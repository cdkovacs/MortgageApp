#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFileSync, spawn } from "node:child_process";
import { readFile, mkdir } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { homedir } from "node:os";
const WORKSPACE_ROOT = process.env.WORKSPACE_ROOT ?? process.cwd();
const JCLX_BIN = "/MVS1/var/jclexpert/bin/jclx";
const JCLX_NLS = "/MVS1/var/jclexpert/nls/english.txt";
// ---------------------------------------------------------------------------
// Resolve SSH connection details from Zowe config once at startup.
// Fall back to env vars so the server still works outside a Zowe workspace.
// ---------------------------------------------------------------------------
function resolveZoweSSH() {
    try {
        const raw = execFileSync("zowe", ["config", "list", "--rfj"], {
            encoding: "utf8",
            env: process.env,
            cwd: WORKSPACE_ROOT,
            timeout: 10_000,
        });
        const d = JSON.parse(raw);
        const profiles = d.data?.profiles ?? {};
        const base = profiles.project_base?.properties ?? {};
        const ssh = profiles.ssh?.properties ?? {};
        // 'user' comes from secure store — not in plaintext config. Fall back to
        // JCLX_SSH_USER env var, then ~/.ssh/config or the OS credential manager.
        return {
            host: process.env.JCLX_SSH_HOST ?? base.host ?? "localhost",
            port: Number(process.env.JCLX_SSH_PORT ?? ssh.port ?? 22),
            user: process.env.JCLX_SSH_USER ?? ssh.user ?? base.user,
            keyFile: process.env.JCLX_SSH_KEY ?? ssh.keyFile,
        };
    }
    catch {
        return {
            host: process.env.JCLX_SSH_HOST ?? "localhost",
            port: Number(process.env.JCLX_SSH_PORT ?? 22),
            user: process.env.JCLX_SSH_USER,
            keyFile: process.env.JCLX_SSH_KEY,
        };
    }
}
const { host: SSH_HOST, port: SSH_PORT, user: SSH_USER, keyFile: SSH_KEY } = resolveZoweSSH();
// SSH ControlMaster socket dir — reuses the TCP+auth handshake across calls.
const CONTROL_DIR = resolve(homedir(), ".ssh", "jclx-ctl");
const CONTROL_PATH = resolve(CONTROL_DIR, `${SSH_HOST}_%p.sock`);
// Ensure the ControlMaster socket directory exists at startup.
mkdir(CONTROL_DIR, { recursive: true }).catch(() => { });
/**
 * Build the ssh argument list that is common to every invocation.
 * ControlMaster=auto means the first call opens the master; subsequent calls
 * reuse it and return almost immediately after the SSH handshake.
 */
function sshArgs(remoteCmd) {
    const args = [
        "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "-o", `ControlMaster=auto`,
        "-o", `ControlPath=${CONTROL_PATH}`,
        "-o", "ControlPersist=120", // keep master alive for 120 s of idle
        "-p", String(SSH_PORT),
    ];
    if (SSH_USER) {
        args.push("-l", SSH_USER);
    }
    if (SSH_KEY) {
        args.push("-i", SSH_KEY, "-o", "IdentitiesOnly=yes");
    }
    args.push(SSH_HOST, remoteCmd);
    return args;
}
/**
 * Spawn an ssh command and return stdout+stderr as a string.
 * jclx exits 4 (warnings) or 8 (errors) — both are valid analysis results.
 */
function runSSH(remoteCmd, stdin) {
    return new Promise((res, rej) => {
        const proc = spawn("ssh", sshArgs(remoteCmd), { env: process.env });
        if (stdin !== undefined) {
            proc.stdin.write(stdin, "utf8");
            proc.stdin.end();
        }
        let stdout = "";
        let stderr = "";
        proc.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
        proc.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
        proc.on("close", (code) => {
            const output = (stdout + (stderr ? `\n[stderr]\n${stderr}` : "")).trim();
            // jclx returns 4 for warnings, 8 for errors-in-JCL — treat ≤8 as success
            if (code !== null && code > 8) {
                rej(new Error(output || `ssh exited with code ${code}`));
            }
            else {
                res(output);
            }
        });
        proc.on("error", (err) => rej(err));
    });
}
// ---------------------------------------------------------------------------
function buildJclxArgs(opts) {
    const args = [];
    if (opts.output)
        args.push("-o", opts.output);
    if (opts.dsnCheck)
        args.push("-c", opts.dsnCheck);
    if (opts.logLevel)
        args.push("-l", opts.logLevel);
    if (opts.rulesFile)
        args.push("-r", opts.rulesFile);
    if (opts.jobClass)
        args.push("-j", opts.jobClass);
    if (opts.aliasDsn)
        args.push("-a", opts.aliasDsn);
    return args;
}
/**
 * Run jclx on an existing USS file — single SSH round-trip.
 */
async function runJclx(ussPath, opts) {
    const quotedArgs = buildJclxArgs(opts).map((a) => `'${a}'`).join(" ");
    const remoteCmd = `JCLX_NLS='${JCLX_NLS}' '${JCLX_BIN}' ${quotedArgs} '${ussPath}'`;
    return runSSH(remoteCmd);
}
/**
 * Stream JCL content into a single SSH command (cat > tmp && jclx && rm),
 * eliminating both the Zowe upload round-trip and the separate Zowe CLI process.
 */
async function runJclxOnContent(jclContent, filename, opts) {
    const tmpUssPath = `/tmp/jclx-${Date.now()}-${basename(filename)}`;
    const quotedArgs = buildJclxArgs(opts).map((a) => `'${a}'`).join(" ");
    const remoteCmd = `cat > '${tmpUssPath}' && { JCLX_NLS='${JCLX_NLS}' '${JCLX_BIN}' ${quotedArgs} '${tmpUssPath}'; ` +
        `rc=$?; rm -f '${tmpUssPath}'; exit $rc; } || { rm -f '${tmpUssPath}'; exit 1; }`;
    return runSSH(remoteCmd, jclContent);
}
/**
 * Read a local file and analyse it via a single SSH round-trip.
 */
async function uploadAndAnalyse(localPath, opts) {
    const content = await readFile(localPath, "utf8");
    return runJclxOnContent(content, basename(localPath), opts);
}
// ---------------------------------------------------------------------------
const server = new McpServer({ name: "jcl-expert", version: "0.1.0" });
// ---------------------------------------------------------------------------
// TOOL: analyse-jcl-local-file
// ---------------------------------------------------------------------------
server.registerTool("analyse-jcl-local-file", {
    description: "Run IBM JCL Expert (jclx) against a local JCL file on the workstation. " +
        "The file is uploaded to USS, analysed, then the temp copy is deleted. " +
        "Returns jclx findings in the requested format (default: text).",
    inputSchema: z.object({
        localPath: z.string().describe("Absolute or workspace-relative path to the local JCL file, e.g. src/jcl/RUNNBR.jcl"),
        output: z.enum(["json", "text", "rexx"]).optional().default("text")
            .describe("Output format for jclx results (default: text)"),
        dsnCheck: z.enum(["ON", "OFF", "DISP"]).optional()
            .describe("DSN checking level (-c). ON=check, OFF=skip, DISP=disposition only"),
        jobClass: z.string().optional()
            .describe("Default job class to assume (-j), e.g. A"),
        rulesFile: z.string().optional()
            .describe("USS path to a jclx jobcard rules file (-r)"),
        aliasDsn: z.string().optional()
            .describe("Alias DSN for resolving catalogued data sets (-a)"),
    }),
}, async ({ localPath, output, dsnCheck, jobClass, rulesFile, aliasDsn }) => {
    try {
        const absPath = resolve(WORKSPACE_ROOT, localPath);
        const result = await uploadAndAnalyse(absPath, { output, dsnCheck, jobClass, rulesFile, aliasDsn });
        return { content: [{ type: "text", text: result }] };
    }
    catch (err) {
        return { content: [{ type: "text", text: String(err) }], isError: true };
    }
});
// ---------------------------------------------------------------------------
// TOOL: analyse-jcl-uss-file
// ---------------------------------------------------------------------------
server.registerTool("analyse-jcl-uss-file", {
    description: "Run IBM JCL Expert (jclx) against a JCL file that already exists on USS. " +
        "Returns jclx findings in the requested format (default: text).",
    inputSchema: z.object({
        ussPath: z.string().describe("Absolute USS path to the JCL file, e.g. /u/drice/jcl/myjob.jcl"),
        output: z.enum(["json", "text", "rexx"]).optional().default("text")
            .describe("Output format for jclx results (default: text)"),
        dsnCheck: z.enum(["ON", "OFF", "DISP"]).optional()
            .describe("DSN checking level (-c). ON=check, OFF=skip, DISP=disposition only"),
        jobClass: z.string().optional()
            .describe("Default job class to assume (-j), e.g. A"),
        rulesFile: z.string().optional()
            .describe("USS path to a jclx jobcard rules file (-r)"),
        aliasDsn: z.string().optional()
            .describe("Alias DSN for resolving catalogued data sets (-a)"),
    }),
}, async ({ ussPath, output, dsnCheck, jobClass, rulesFile, aliasDsn }) => {
    try {
        const result = await runJclx(ussPath, { output, dsnCheck, jobClass, rulesFile, aliasDsn });
        return { content: [{ type: "text", text: result }] };
    }
    catch (err) {
        return { content: [{ type: "text", text: String(err) }], isError: true };
    }
});
// ---------------------------------------------------------------------------
// TOOL: analyse-jcl-inline
// ---------------------------------------------------------------------------
server.registerTool("analyse-jcl-inline", {
    description: "Run IBM JCL Expert (jclx) against inline JCL text. " +
        "The JCL is written to a temp file on USS, analysed, then deleted. " +
        "Returns jclx findings in the requested format (default: text).",
    inputSchema: z.object({
        jcl: z.string().describe("The complete JCL text to analyse"),
        output: z.enum(["json", "text", "rexx"]).optional().default("text")
            .describe("Output format for jclx results (default: text)"),
        dsnCheck: z.enum(["ON", "OFF", "DISP"]).optional()
            .describe("DSN checking level (-c)"),
        jobClass: z.string().optional()
            .describe("Default job class to assume (-j), e.g. A"),
        rulesFile: z.string().optional()
            .describe("USS path to a jclx jobcard rules file (-r)"),
        aliasDsn: z.string().optional()
            .describe("Alias DSN for resolving catalogued data sets (-a)"),
    }),
}, async ({ jcl, output, dsnCheck, jobClass, rulesFile, aliasDsn }) => {
    try {
        const result = await runJclxOnContent(jcl, "inline.jcl", { output, dsnCheck, jobClass, rulesFile, aliasDsn });
        return { content: [{ type: "text", text: result }] };
    }
    catch (err) {
        return { content: [{ type: "text", text: String(err) }], isError: true };
    }
});
// ---------------------------------------------------------------------------
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error(`jcl-expert MCP server running on stdio (ssh → ${SSH_HOST}:${SSH_PORT}, ControlMaster enabled)`);
}
main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
