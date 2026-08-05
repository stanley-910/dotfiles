/**
 * Starshipline
 *
 * A Pi footer/theme extension that borrows colors and symbols from the real
 * `starship.toml`, while rendering a Pi-native footer with coding-agent stats.
 */

import { execFile } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { promisify } from "node:util";
import { getAgentDir, Theme, type ExtensionAPI, type ExtensionContext, type ThemeColor } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const execFileAsync = promisify(execFile);

type ThemeBg = "selectedBg" | "userMessageBg" | "customMessageBg" | "toolPendingBg" | "toolSuccessBg" | "toolErrorBg";
type ThemeValue = string | number;
type FgColors = Record<ThemeColor, ThemeValue>;
type BgColors = Record<ThemeBg, ThemeValue>;
type LeftMode = "clean" | "starship";
type ExtensionThemePreset = "from-starship" | "starship-nord" | "starship-aurora" | "starship-muted";

interface StarshiplineConfig {
	enabled: boolean;
	starshipConfig: string;
	refreshIntervalMs: number;
	leftMode: LeftMode;
	pathMaxSegments: number;
	stripPromptCharacter: boolean;
	showGitStatus: boolean;
	showPiStats: boolean;
	showTokenStats: boolean;
	showCacheEfficiency: boolean;
	showCacheTotals: boolean;
	showContextMeter: boolean;
	contextMeterWidth: number;
	showCost: boolean;
	showModel: boolean;
	showThinkingLevel: boolean;
	showExtensionStatuses: boolean;
	applyPiTheme: boolean;
	themePreset: ExtensionThemePreset | `pi:${string}`;
	colorOverrides: Record<string, ThemeValue>;
}

interface StarshipStyles {
	directoryStyle?: string;
	beforeRepoRootStyle?: string;
	repoRootStyle?: string;
	gitBranchStyle?: string;
	gitStatusStyle?: string;
	gitBranchSymbol: string;
}

interface GitInfo {
	root?: string;
	branch?: string;
	ahead: number;
	behind: number;
	staged: number;
	modified: number;
	untracked: number;
	deleted: number;
	renamed: number;
	conflicted: number;
	stashed: number;
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
}

const CONFIG_PATH = join(getAgentDir(), "starshipline.json");
const DEFAULT_STARSHIP_CONFIG = process.env.STARSHIP_CONFIG || "~/.config/starship.toml";
const VISIBLE_EXTENSION_STATUS_KEYS = new Set(["pi-talk", "rpiv-workflow", "subagents"]);
const PI_TALK_PLAY_ICON = "▶";
const PI_TALK_PAUSE_ICON = "Ⅱ";

const DEFAULT_CONFIG: StarshiplineConfig = {
	enabled: true,
	starshipConfig: DEFAULT_STARSHIP_CONFIG,
	refreshIntervalMs: 5000,
	leftMode: "clean",
	pathMaxSegments: 5,
	stripPromptCharacter: true,
	showGitStatus: true,
	showPiStats: true,
	showTokenStats: false,
	showCacheEfficiency: false,
	showCacheTotals: false,
	showContextMeter: true,
	contextMeterWidth: 10,
	showCost: false,
	showModel: true,
	showThinkingLevel: true,
	showExtensionStatuses: true,
	applyPiTheme: true,
	themePreset: "from-starship",
	colorOverrides: {},
};

const NORD_FG: FgColors = {
	accent: "#6582bf",
	border: "#8fbcbb",
	borderAccent: "#d6ad5e",
	borderMuted: "#4c566a",
	success: "#a3be8c",
	error: "#bf616a",
	warning: "#ebcb8b",
	muted: "#8a99ba",
	dim: "#6272a4",
	text: "",
	thinkingText: "#8a99ba",
	userMessageText: "",
	customMessageText: "",
	customMessageLabel: "#8fbcbb",
	toolTitle: "#8fbcbb",
	toolOutput: "",
	mdHeading: "#d6ad5e",
	mdLink: "#8fbcbb",
	mdLinkUrl: "#6272a4",
	mdCode: "#b48ead",
	mdCodeBlock: "",
	mdCodeBlockBorder: "#4c566a",
	mdQuote: "#8a99ba",
	mdQuoteBorder: "#4c566a",
	mdHr: "#4c566a",
	mdListBullet: "#8fbcbb",
	toolDiffAdded: "#a3be8c",
	toolDiffRemoved: "#bf616a",
	toolDiffContext: "#6272a4",
	syntaxComment: "#6272a4",
	syntaxKeyword: "#b48ead",
	syntaxFunction: "#8fbcbb",
	syntaxVariable: "#d6ad5e",
	syntaxString: "#a3be8c",
	syntaxNumber: "#d08770",
	syntaxType: "#6582bf",
	syntaxOperator: "#8fbcbb",
	syntaxPunctuation: "#8a99ba",
	thinkingOff: "#4c566a",
	thinkingMinimal: "#8fbcbb",
	thinkingLow: "#6582bf",
	thinkingMedium: "#d6ad5e",
	thinkingHigh: "#b48ead",
	thinkingXhigh: "#bf616a",
	bashMode: "#d6ad5e",
};

const NORD_BG: BgColors = {
	selectedBg: "#3b4252",
	userMessageBg: "#2e3440",
	customMessageBg: "#2e3440",
	toolPendingBg: "#2e3440",
	toolSuccessBg: "#243326",
	toolErrorBg: "#3a2528",
};

const FG_TOKENS = Object.keys(NORD_FG) as ThemeColor[];
const BG_TOKENS = Object.keys(NORD_BG) as ThemeBg[];
const EXTENSION_PRESETS: ExtensionThemePreset[] = ["from-starship", "starship-nord", "starship-aurora", "starship-muted"];
const COMMON_COLOR_TOKENS = [
	"accent",
	"border",
	"borderAccent",
	"borderMuted",
	"success",
	"error",
	"warning",
	"muted",
	"dim",
	"toolTitle",
	"mdHeading",
	"mdLink",
	"mdCode",
	"syntaxKeyword",
	"syntaxFunction",
	"syntaxString",
	"syntaxVariable",
	"thinkingLow",
	"thinkingMedium",
	"thinkingHigh",
	"thinkingXhigh",
	"bashMode",
	"selectedBg",
	"userMessageBg",
	"toolPendingBg",
	"toolSuccessBg",
	"toolErrorBg",
];

const NAMED_STYLE_COLORS: Record<string, string> = {
	black: "#2e3440",
	blue: "#5e81ac",
	cyan: "#8fbcbb",
	green: "#a3be8c",
	grey: "#6272a4",
	gray: "#6272a4",
	magenta: "#b48ead",
	orange: "#d08770",
	purple: "#b48ead",
	red: "#bf616a",
	white: "#d8dee9",
	yellow: "#ebcb8b",
	"bright-black": "#4c566a",
	"bright-blue": "#81a1c1",
	"bright-cyan": "#88c0d0",
	"bright-green": "#a3be8c",
	"bright-magenta": "#b48ead",
	"bright-purple": "#b48ead",
	"bright-red": "#bf616a",
	"bright-white": "#eceff4",
	"bright-yellow": "#ebcb8b",
};

const RESET = "\x1b[0m";

function cloneFg(base: FgColors = NORD_FG): FgColors {
	return { ...base };
}

function cloneBg(base: BgColors = NORD_BG): BgColors {
	return { ...base };
}

function isFgToken(token: string): token is ThemeColor {
	return FG_TOKENS.includes(token as ThemeColor);
}

function isBgToken(token: string): token is ThemeBg {
	return BG_TOKENS.includes(token as ThemeBg);
}

function expandHome(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith("~/")) return join(homedir(), path.slice(2));
	return path.replace(/^\$HOME(?=\/|$)/, homedir());
}

function parseThemeValue(input: string): ThemeValue | undefined {
	const value = input.trim();
	if (value === "" || value === "default" || value === "terminal" || value === '""') return "";
	if (/^#[0-9a-f]{6}$/i.test(value)) return value.toLowerCase();
	if (/^\d{1,3}$/.test(value)) {
		const n = Number(value);
		if (n >= 0 && n <= 255) return n;
	}
	return undefined;
}

function sanitizeColorOverrides(input: unknown): Record<string, ThemeValue> {
	if (!input || typeof input !== "object") return {};

	const overrides: Record<string, ThemeValue> = {};
	for (const [token, rawValue] of Object.entries(input)) {
		if (!isFgToken(token) && !isBgToken(token)) continue;

		if (typeof rawValue === "number" && rawValue >= 0 && rawValue <= 255) {
			overrides[token] = rawValue;
			continue;
		}

		if (typeof rawValue === "string") {
			const value = parseThemeValue(rawValue);
			if (value !== undefined) overrides[token] = value;
		}
	}
	return overrides;
}

function sanitizeLeftMode(value: unknown): LeftMode {
	return value === "starship" ? "starship" : "clean";
}

function coerceConfig(input: unknown): StarshiplineConfig {
	if (!input || typeof input !== "object") return { ...DEFAULT_CONFIG };
	const raw = input as Partial<StarshiplineConfig>;
	const preset = typeof raw.themePreset === "string" ? raw.themePreset : DEFAULT_CONFIG.themePreset;

	return {
		enabled: typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_CONFIG.enabled,
		starshipConfig: typeof raw.starshipConfig === "string" ? raw.starshipConfig : DEFAULT_CONFIG.starshipConfig,
		refreshIntervalMs:
			typeof raw.refreshIntervalMs === "number" && raw.refreshIntervalMs >= 0
				? raw.refreshIntervalMs
				: DEFAULT_CONFIG.refreshIntervalMs,
		leftMode: sanitizeLeftMode(raw.leftMode),
		pathMaxSegments:
			typeof raw.pathMaxSegments === "number" && raw.pathMaxSegments >= 3 ? raw.pathMaxSegments : DEFAULT_CONFIG.pathMaxSegments,
		stripPromptCharacter:
			typeof raw.stripPromptCharacter === "boolean" ? raw.stripPromptCharacter : DEFAULT_CONFIG.stripPromptCharacter,
		showGitStatus: typeof raw.showGitStatus === "boolean" ? raw.showGitStatus : DEFAULT_CONFIG.showGitStatus,
		showPiStats: typeof raw.showPiStats === "boolean" ? raw.showPiStats : DEFAULT_CONFIG.showPiStats,
		showTokenStats: typeof raw.showTokenStats === "boolean" ? raw.showTokenStats : DEFAULT_CONFIG.showTokenStats,
		showCacheEfficiency:
			typeof raw.showCacheEfficiency === "boolean" ? raw.showCacheEfficiency : DEFAULT_CONFIG.showCacheEfficiency,
		showCacheTotals: typeof raw.showCacheTotals === "boolean" ? raw.showCacheTotals : DEFAULT_CONFIG.showCacheTotals,
		showContextMeter: typeof raw.showContextMeter === "boolean" ? raw.showContextMeter : DEFAULT_CONFIG.showContextMeter,
		contextMeterWidth:
			typeof raw.contextMeterWidth === "number" && raw.contextMeterWidth >= 4
				? raw.contextMeterWidth
				: DEFAULT_CONFIG.contextMeterWidth,
		showCost: typeof raw.showCost === "boolean" ? raw.showCost : DEFAULT_CONFIG.showCost,
		showModel: typeof raw.showModel === "boolean" ? raw.showModel : DEFAULT_CONFIG.showModel,
		showThinkingLevel:
			typeof raw.showThinkingLevel === "boolean" ? raw.showThinkingLevel : DEFAULT_CONFIG.showThinkingLevel,
		showExtensionStatuses:
			typeof raw.showExtensionStatuses === "boolean" ? raw.showExtensionStatuses : DEFAULT_CONFIG.showExtensionStatuses,
		applyPiTheme: typeof raw.applyPiTheme === "boolean" ? raw.applyPiTheme : DEFAULT_CONFIG.applyPiTheme,
		themePreset: isKnownThemePreset(preset) ? preset : DEFAULT_CONFIG.themePreset,
		colorOverrides: sanitizeColorOverrides(raw.colorOverrides),
	};
}

function loadConfig(): StarshiplineConfig {
	if (!existsSync(CONFIG_PATH)) return { ...DEFAULT_CONFIG };

	try {
		return coerceConfig(JSON.parse(readFileSync(CONFIG_PATH, "utf8")));
	} catch {
		return { ...DEFAULT_CONFIG };
	}
}

function saveConfig(config: StarshiplineConfig): void {
	mkdirSync(dirname(CONFIG_PATH), { recursive: true });
	writeFileSync(CONFIG_PATH, `${JSON.stringify(config, null, "\t")}\n`, "utf8");
}

function isKnownThemePreset(value: string): value is StarshiplineConfig["themePreset"] {
	return EXTENSION_PRESETS.includes(value as ExtensionThemePreset) || value.startsWith("pi:");
}

function getSection(content: string, section: string): string | undefined {
	const escaped = section.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const header = new RegExp(`^\\[${escaped}\\]\\s*$`, "m");
	const match = header.exec(content);
	if (!match) return undefined;

	const rest = content.slice(match.index + match[0].length);
	const nextSection = rest.search(/^\[/m);
	return nextSection === -1 ? rest : rest.slice(0, nextSection);
}

function getTomlString(content: string, section: string, key: string): string | undefined {
	const sectionBody = getSection(content, section);
	if (!sectionBody) return undefined;
	const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const match = sectionBody.match(new RegExp(`^\\s*${escapedKey}\\s*=\\s*(["'])(.*?)\\1`, "m"));
	return match?.[2];
}

function readStarshipConfig(config: StarshiplineConfig): string | undefined {
	const path = expandHome(config.starshipConfig);
	if (!existsSync(path)) return undefined;
	try {
		return readFileSync(path, "utf8");
	} catch {
		return undefined;
	}
}

function getStarshipStyles(config: StarshiplineConfig): StarshipStyles {
	const content = readStarshipConfig(config) ?? "";
	return {
		directoryStyle: getTomlString(content, "directory", "style") ?? "fg:#8a99ba",
		beforeRepoRootStyle: getTomlString(content, "directory", "before_repo_root_style") ?? "fg:#8fbcbb",
		repoRootStyle: getTomlString(content, "directory", "repo_root_style") ?? "fg:#6582bf bold",
		gitBranchStyle: getTomlString(content, "git_branch", "style") ?? "fg:#b48ead",
		gitStatusStyle: getTomlString(content, "git_status", "style") ?? "fg:#bf616a",
		gitBranchSymbol: getTomlString(content, "git_branch", "symbol") ?? "",
	};
}

function colorFromStarshipStyle(style: string | undefined): ThemeValue | undefined {
	if (!style) return undefined;

	const hex = style.match(/#[0-9a-f]{6}/i)?.[0];
	if (hex) return hex.toLowerCase();

	const indexed = style.match(/(?:^|\s)fg:(\d{1,3})(?:\s|$)/)?.[1] ?? style.match(/(?:^|\s)(\d{1,3})(?:\s|$)/)?.[1];
	if (indexed) {
		const value = Number(indexed);
		if (value >= 0 && value <= 255) return value;
	}

	const words = style.toLowerCase().split(/\s+/).filter((part) => !["bold", "italic", "underline", "dimmed"].includes(part));
	for (const word of words) {
		const normalized = word.replace(/^fg:/, "");
		if (NAMED_STYLE_COLORS[normalized]) return NAMED_STYLE_COLORS[normalized];
	}

	return undefined;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } | undefined {
	const match = hex.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
	if (!match) return undefined;
	return { r: Number.parseInt(match[1], 16), g: Number.parseInt(match[2], 16), b: Number.parseInt(match[3], 16) };
}

function fgAnsiForColor(color: ThemeValue | undefined): string {
	if (color === undefined || color === "") return "";
	if (typeof color === "number") return `\x1b[38;5;${color}m`;
	const rgb = hexToRgb(color);
	return rgb ? `\x1b[38;2;${rgb.r};${rgb.g};${rgb.b}m` : "";
}

function styleText(style: string | undefined, text: string): string {
	if (!style || text.length === 0) return text;

	const codes: string[] = [];
	if (/\bbold\b/i.test(style)) codes.push("\x1b[1m");
	if (/\bitalic\b/i.test(style)) codes.push("\x1b[3m");
	if (/\bunderline\b/i.test(style)) codes.push("\x1b[4m");
	codes.push(fgAnsiForColor(colorFromStarshipStyle(style)));

	const prefix = codes.filter(Boolean).join("");
	return prefix ? `${prefix}${text}${RESET}` : text;
}

function applyIfPresent<T extends string>(target: Record<T, ThemeValue>, key: T, value: ThemeValue | undefined): void {
	if (value !== undefined) target[key] = value;
}

function buildThemeFromStarshipToml(config: StarshiplineConfig): { fg: FgColors; bg: BgColors } {
	const fg = cloneFg();
	const bg = cloneBg();
	const styles = getStarshipStyles(config);
	const content = readStarshipConfig(config);
	if (!content) return { fg, bg };

	const user = colorFromStarshipStyle(getTomlString(content, "username", "style_user"));
	const directory = colorFromStarshipStyle(styles.directoryStyle);
	const beforeRepoRoot = colorFromStarshipStyle(styles.beforeRepoRootStyle);
	const repoRoot = colorFromStarshipStyle(styles.repoRootStyle);
	const gitBranch = colorFromStarshipStyle(styles.gitBranchStyle);
	const gitStatus = colorFromStarshipStyle(styles.gitStatusStyle);
	const successSymbol = colorFromStarshipStyle(getTomlString(content, "character", "success_symbol"));
	const errorSymbol = colorFromStarshipStyle(getTomlString(content, "character", "error_symbol"));

	applyIfPresent(fg, "accent", repoRoot ?? successSymbol);
	applyIfPresent(fg, "border", beforeRepoRoot ?? repoRoot);
	applyIfPresent(fg, "borderAccent", user ?? repoRoot);
	applyIfPresent(fg, "muted", directory);
	applyIfPresent(fg, "dim", successSymbol);
	applyIfPresent(fg, "warning", user);
	applyIfPresent(fg, "error", gitStatus ?? errorSymbol);
	applyIfPresent(fg, "toolTitle", beforeRepoRoot ?? repoRoot);
	applyIfPresent(fg, "customMessageLabel", beforeRepoRoot ?? repoRoot);
	applyIfPresent(fg, "mdHeading", user);
	applyIfPresent(fg, "mdLink", beforeRepoRoot ?? repoRoot);
	applyIfPresent(fg, "mdCode", gitBranch);
	applyIfPresent(fg, "syntaxKeyword", gitBranch);
	applyIfPresent(fg, "syntaxFunction", beforeRepoRoot ?? repoRoot);
	applyIfPresent(fg, "syntaxVariable", user);
	applyIfPresent(fg, "syntaxType", repoRoot);
	applyIfPresent(fg, "thinkingLow", repoRoot);
	applyIfPresent(fg, "thinkingMedium", user);
	applyIfPresent(fg, "thinkingHigh", gitBranch);
	applyIfPresent(fg, "thinkingXhigh", gitStatus ?? errorSymbol);
	applyIfPresent(fg, "bashMode", user);

	return { fg, bg };
}

function buildPresetTheme(config: StarshiplineConfig): Theme {
	let fg = cloneFg();
	let bg = cloneBg();

	if (config.themePreset === "from-starship") {
		const derived = buildThemeFromStarshipToml(config);
		fg = derived.fg;
		bg = derived.bg;
	} else if (config.themePreset === "starship-aurora") {
		fg = {
			...cloneFg(),
			accent: "#88c0d0",
			border: "#81a1c1",
			borderAccent: "#ebcb8b",
			muted: "#81a1c1",
			dim: "#5e81ac",
			mdLink: "#88c0d0",
			mdCode: "#d08770",
			syntaxFunction: "#88c0d0",
			syntaxVariable: "#ebcb8b",
			thinkingLow: "#81a1c1",
			thinkingMedium: "#88c0d0",
			thinkingHigh: "#ebcb8b",
			thinkingXhigh: "#bf616a",
		};
	} else if (config.themePreset === "starship-muted") {
		fg = {
			...cloneFg(),
			accent: "#8a99ba",
			border: "#6272a4",
			borderAccent: "#8fbcbb",
			muted: "#6272a4",
			dim: "#4c566a",
			warning: "#d6ad5e",
			mdHeading: "#8a99ba",
			mdLink: "#8fbcbb",
			syntaxKeyword: "#8a99ba",
			syntaxFunction: "#8fbcbb",
		};
		bg = {
			...cloneBg(),
			selectedBg: "#323946",
			userMessageBg: "#252b35",
			customMessageBg: "#252b35",
			toolPendingBg: "#252b35",
		};
	}

	for (const [token, value] of Object.entries(config.colorOverrides)) {
		if (isFgToken(token)) fg[token] = value;
		if (isBgToken(token)) bg[token] = value;
	}

	return new Theme(fg, bg, "truecolor", { name: `starshipline:${config.themePreset}` });
}

function compactPathSegments(displayPath: string, maxSegments: number): string {
	const prefix = displayPath.startsWith(`~${sep}`) ? `~${sep}` : displayPath.startsWith("/") ? "/" : "";
	const rest = displayPath.slice(prefix.length);
	const parts = rest.split(sep).filter(Boolean);
	if (parts.length <= maxSegments) return displayPath;
	return `${prefix}…${sep}${parts.slice(-(maxSegments - 1)).join(sep)}`;
}

function formatPathForFooter(cwd: string, maxSegments: number): string {
	const home = homedir();
	const resolvedCwd = resolve(cwd);
	const resolvedHome = resolve(home);
	const relativeToHome = relative(resolvedHome, resolvedCwd);
	const insideHome = relativeToHome === "" || (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`));
	const displayPath = insideHome ? (relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`) : resolvedCwd;
	return compactPathSegments(displayPath, maxSegments);
}

function stylePath(displayPath: string, gitRoot: string | undefined, styles: StarshipStyles): string {
	if (!gitRoot) return styleText(styles.directoryStyle, displayPath);

	const rootDisplay = formatPathForFooter(gitRoot, Number.MAX_SAFE_INTEGER);
	if (!displayPath.startsWith(rootDisplay)) return styleText(styles.directoryStyle, displayPath);

	const repoRootName = basename(rootDisplay);
	const repoRootStart = rootDisplay.length - repoRootName.length;
	const beforeRoot = displayPath.slice(0, repoRootStart);
	const repoRoot = displayPath.slice(repoRootStart, repoRootStart + repoRootName.length);
	const afterRoot = displayPath.slice(repoRootStart + repoRootName.length);

	return [
		styleText(styles.beforeRepoRootStyle, beforeRoot),
		styleText(styles.repoRootStyle, repoRoot),
		styleText(styles.directoryStyle, afterRoot),
	].join("");
}

async function execGit(cwd: string, args: string[]): Promise<string | undefined> {
	try {
		const { stdout } = await execFileAsync("git", ["-C", cwd, "--no-optional-locks", ...args], {
			cwd,
			encoding: "utf8",
			timeout: 1500,
			maxBuffer: 512 * 1024,
		});
		return String(stdout).trimEnd();
	} catch {
		return undefined;
	}
}

function parsePorcelainStatus(output: string | undefined): Partial<GitInfo> {
	const status: Partial<GitInfo> = {
		ahead: 0,
		behind: 0,
		staged: 0,
		modified: 0,
		untracked: 0,
		deleted: 0,
		renamed: 0,
		conflicted: 0,
		stashed: 0,
	};
	if (!output) return status;

	for (const line of output.split("\n")) {
		if (line.startsWith("# branch.head ")) {
			const branch = line.slice("# branch.head ".length).trim();
			if (branch && branch !== "(detached)") status.branch = branch;
			continue;
		}
		if (line.startsWith("# branch.ab ")) {
			const match = line.match(/\+(\d+)\s+-(\d+)/);
			if (match) {
				status.ahead = Number(match[1]);
				status.behind = Number(match[2]);
			}
			continue;
		}
		if (line.startsWith("# stash ")) {
			status.stashed = Number(line.slice("# stash ".length).trim()) || 0;
			continue;
		}
		if (line.startsWith("? ")) {
			status.untracked = (status.untracked ?? 0) + 1;
			continue;
		}
		if (line.startsWith("u ")) {
			status.conflicted = (status.conflicted ?? 0) + 1;
			continue;
		}
		if (line.startsWith("1 ") || line.startsWith("2 ")) {
			const xy = line.slice(2, 4);
			const [indexStatus, worktreeStatus] = xy.split("");
			if (indexStatus && indexStatus !== ".") status.staged = (status.staged ?? 0) + 1;
			if (worktreeStatus && worktreeStatus !== ".") status.modified = (status.modified ?? 0) + 1;
			if (indexStatus === "D" || worktreeStatus === "D") status.deleted = (status.deleted ?? 0) + 1;
			if (line.startsWith("2 ") || indexStatus === "R") status.renamed = (status.renamed ?? 0) + 1;
		}
	}

	return status;
}

async function getGitInfo(cwd: string): Promise<GitInfo | undefined> {
	const [root, porcelain] = await Promise.all([
		execGit(cwd, ["rev-parse", "--show-toplevel"]),
		execGit(cwd, ["status", "--porcelain=v2", "--branch", "--show-stash"]),
	]);
	if (!root && !porcelain) return undefined;

	const parsed = parsePorcelainStatus(porcelain);
	return {
		root: root?.trim(),
		branch: parsed.branch,
		ahead: parsed.ahead ?? 0,
		behind: parsed.behind ?? 0,
		staged: parsed.staged ?? 0,
		modified: parsed.modified ?? 0,
		untracked: parsed.untracked ?? 0,
		deleted: parsed.deleted ?? 0,
		renamed: parsed.renamed ?? 0,
		conflicted: parsed.conflicted ?? 0,
		stashed: parsed.stashed ?? 0,
	};
}

function countSuffix(count: number): string {
	return count > 1 ? String(count) : "";
}

function buildGitText(git: GitInfo | undefined, styles: StarshipStyles): string {
	if (!git?.branch) return "";

	const branch = styleText(styles.gitBranchStyle, `${styles.gitBranchSymbol} ${git.branch}`);
	const statusParts: string[] = [];
	if (git.staged) statusParts.push(`+${countSuffix(git.staged)}`);
	if (git.modified) statusParts.push(`!${countSuffix(git.modified)}`);
	if (git.untracked) statusParts.push(`?${countSuffix(git.untracked)}`);
	if (git.deleted) statusParts.push(`✘${countSuffix(git.deleted)}`);
	if (git.renamed) statusParts.push(`»${countSuffix(git.renamed)}`);
	if (git.conflicted) statusParts.push(`=${countSuffix(git.conflicted)}`);
	if (git.stashed) statusParts.push(`$${countSuffix(git.stashed)}`);
	if (git.ahead && git.behind) statusParts.push(`⇕${git.ahead}/${git.behind}`);
	else if (git.ahead) statusParts.push(`↑${countSuffix(git.ahead)}`);
	else if (git.behind) statusParts.push(`↓${countSuffix(git.behind)}`);

	return statusParts.length ? `${branch} ${styleText(styles.gitStatusStyle, statusParts.join(""))}` : branch;
}

async function buildCleanLeftLine(ctx: ExtensionContext, config: StarshiplineConfig): Promise<string> {
	const styles = getStarshipStyles(config);
	const git = config.showGitStatus ? await getGitInfo(ctx.cwd) : undefined;
	const path = stylePath(formatPathForFooter(ctx.cwd, config.pathMaxSegments), git?.root, styles);
	const gitText = config.showGitStatus ? buildGitText(git, styles) : "";
	return gitText ? `${path} ${gitText}` : path;
}

function cleanupStarshipOutput(output: string, stripPromptCharacter: boolean): string {
	const lines = output
		.replace(/\x1b\[J/g, "")
		.replace(/\r/g, "")
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean);

	let line = lines.join(" ").replace(/\s+$/g, "");
	if (stripPromptCharacter) {
		line = line.replace(/\s*(?:\x1b\[[0-9;]*m)*(?:[$❯➜✦:])(?:\x1b\[[0-9;]*m)*\s*$/u, "");
	}
	return line;
}

async function buildStarshipLeftLine(ctx: ExtensionContext, config: StarshiplineConfig, width: number): Promise<string> {
	const env = {
		...process.env,
		STARSHIP_CONFIG: expandHome(config.starshipConfig),
		STARSHIP_SHELL: "unknown",
	};
	const { stdout } = await execFileAsync(
		"starship",
		[
			"prompt",
			"--path",
			ctx.cwd,
			"--logical-path",
			ctx.cwd,
			"--terminal-width",
			String(width),
			"--status",
			"0",
			"--cmd-duration",
			"0",
		],
		{ cwd: ctx.cwd, env, encoding: "utf8", timeout: 2000, maxBuffer: 1024 * 1024 },
	);
	return cleanupStarshipOutput(String(stdout), config.stripPromptCharacter);
}

function formatTokens(count: number): string {
	if (count < 1000) return String(count);
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function getUsageStats(ctx: ExtensionContext): UsageStats {
	let input = 0;
	let output = 0;
	let cacheRead = 0;
	let cacheWrite = 0;
	let cost = 0;

	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;
		const usage = (entry.message as {
			usage?: {
				input?: number;
				output?: number;
				cacheRead?: number;
				cacheWrite?: number;
				cost?: { total?: number };
			};
		}).usage;
		input += usage?.input ?? 0;
		output += usage?.output ?? 0;
		cacheRead += usage?.cacheRead ?? 0;
		cacheWrite += usage?.cacheWrite ?? 0;
		cost += usage?.cost?.total ?? 0;
	}

	return { input, output, cacheRead, cacheWrite, cost };
}

function isUsingSubscription(ctx: ExtensionContext): boolean {
	if (!ctx.model) return false;
	return ctx.modelRegistry.isUsingOAuth(ctx.model);
}

function buildContextMeter(ctx: ExtensionContext, config: StarshiplineConfig, theme: ExtensionContext["ui"]["theme"]): string {
	const usage = ctx.getContextUsage();
	const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
	const percent = usage?.percent;
	const tokens = usage?.tokens;
	const tokenUsage = `${tokens === null || tokens === undefined ? "?" : formatTokens(tokens)}/${
		contextWindow ? formatTokens(contextWindow) : "?"
	}`;
	const width = Math.max(4, Math.round(config.contextMeterWidth));

	if (percent === null || percent === undefined) {
		return theme.fg("dim", `?% ${"░".repeat(width)} ${tokenUsage}`);
	}

	const filled = Math.max(0, Math.min(width, Math.round((percent / 100) * width)));
	const bar = `${"█".repeat(filled)}${"░".repeat(width - filled)}`;
	const color: ThemeColor = percent > 90 ? "error" : percent > 70 ? "warning" : percent > 50 ? "accent" : "muted";
	return theme.fg(color, `${percent.toFixed(0)}% ${bar} ${tokenUsage}`);
}

function buildCacheEfficiency(stats: UsageStats): string | undefined {
	if (!stats.cacheRead) return undefined;
	const denominator = stats.input + stats.cacheRead;
	if (!denominator) return undefined;
	return `cache ${Math.round((stats.cacheRead / denominator) * 100)}%`;
}

function formatExtensionStatus(key: string, value: string): string {
	const compact = value.replace(/\s*·\s*/g, "·");
	if (key !== "pi-talk") return compact;

	const speed = compact.match(/·(.+)$/)?.[1];
	const icon = /^talking\b/.test(compact)
		? PI_TALK_PAUSE_ICON
		: /^(?:gagged|paused)\b/.test(compact)
			? PI_TALK_PLAY_ICON
			: undefined;
	if (!icon) return compact;
	return speed ? `${icon}  ${speed}` : icon;
}

export default function starshipline(pi: ExtensionAPI) {
	let config = loadConfig();
	let leftLine = "";
	let leftError: string | undefined;
	let refreshTimer: ReturnType<typeof setInterval> | undefined;
	let refreshInFlight = false;
	let lastWidth = 120;
	let requestRender: (() => void) | undefined;

	function applyTheme(ctx: ExtensionContext): void {
		if (!ctx.hasUI || !config.applyPiTheme) return;

		const result = config.themePreset.startsWith("pi:")
			? ctx.ui.setTheme(config.themePreset.slice("pi:".length))
			: ctx.ui.setTheme(buildPresetTheme(config));

		if (!result.success) ctx.ui.notify(`Starshipline theme failed: ${result.error ?? "unknown error"}`, "warning");
	}

	async function refreshLeft(ctx: ExtensionContext, width = lastWidth): Promise<void> {
		if (refreshInFlight) return;
		refreshInFlight = true;

		try {
			leftLine =
				config.leftMode === "starship"
					? await buildStarshipLeftLine(ctx, config, width)
					: await buildCleanLeftLine(ctx, config);
			leftError = undefined;
		} catch (error) {
			leftLine = "";
			leftError = error instanceof Error ? error.message : String(error);
		} finally {
			refreshInFlight = false;
			requestRender?.();
		}
	}

	function buildModelText(ctx: ExtensionContext, theme: ExtensionContext["ui"]["theme"]): string {
		if (config.showModel && ctx.model) {
			const thinking = config.showThinkingLevel ? pi.getThinkingLevel() : undefined;
			return theme.fg("muted", thinking ? `${ctx.model.id}·${thinking}` : ctx.model.id);
		}
		if (config.showThinkingLevel) return theme.fg("muted", pi.getThinkingLevel());
		return "";
	}

	function buildRightSide(
		ctx: ExtensionContext,
		theme: ExtensionContext["ui"]["theme"],
		footerData: { getExtensionStatuses(): ReadonlyMap<string, string> },
	): string {
		const parts: string[] = [];

		if (config.showExtensionStatuses) {
			for (const [key, value] of footerData.getExtensionStatuses()) {
				if (!VISIBLE_EXTENSION_STATUS_KEYS.has(key) || !value) continue;
				parts.push(formatExtensionStatus(key, value));
			}
		}

		if (config.showPiStats) {
			const needsUsageStats = config.showTokenStats || config.showCacheEfficiency || config.showCacheTotals || config.showCost;
			const stats = needsUsageStats ? getUsageStats(ctx) : undefined;

			if (config.showTokenStats && stats) {
				if (stats.input) parts.push(theme.fg("dim", `↑${formatTokens(stats.input)}`));
				if (stats.output) parts.push(theme.fg("dim", `↓${formatTokens(stats.output)}`));
			}

			if (config.showCacheEfficiency && stats) {
				const efficiency = buildCacheEfficiency(stats);
				if (efficiency) {
					const cacheDetails = config.showCacheTotals
						? [efficiency, `R${formatTokens(stats.cacheRead)}`, stats.cacheWrite ? `W${formatTokens(stats.cacheWrite)}` : undefined]
								.filter(Boolean)
								.join(" ")
						: efficiency;
					parts.push(theme.fg("dim", cacheDetails));
				}
			} else if (config.showCacheTotals && stats) {
				if (stats.cacheRead) parts.push(theme.fg("dim", `R${formatTokens(stats.cacheRead)}`));
				if (stats.cacheWrite) parts.push(theme.fg("dim", `W${formatTokens(stats.cacheWrite)}`));
			}

			if (config.showCost && stats && (stats.cost || isUsingSubscription(ctx))) {
				parts.push(theme.fg("dim", `$${stats.cost.toFixed(3)}${isUsingSubscription(ctx) ? " sub" : ""}`));
			}

			if (config.showContextMeter) parts.push(buildContextMeter(ctx, config, theme));
			else {
				const usage = ctx.getContextUsage();
				const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
				const percent = usage?.percent;
				const tokens = usage?.tokens;
				const tokenUsage = `${tokens === null || tokens === undefined ? "?" : formatTokens(tokens)}/${
					contextWindow ? formatTokens(contextWindow) : "?"
				}`;
				parts.push(theme.fg("dim", `${percent === null || percent === undefined ? "?" : percent.toFixed(1)}% ${tokenUsage}`));
			}
		}

		return parts.join("  ");
	}

	function installFooter(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		if (!config.enabled) {
			ctx.ui.setFooter(undefined);
			return;
		}

		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(() => {
				void refreshLeft(ctx);
				tui.requestRender();
			});

			return {
				dispose: unsubscribe,
				invalidate() {},
				render(width: number): string[] {
					if (width !== lastWidth) {
						lastWidth = width;
						void refreshLeft(ctx, width);
					}

					const fallback = leftError
						? theme.fg("warning", `starshipline unavailable: ${formatPathForFooter(ctx.cwd, config.pathMaxSegments)}`)
						: theme.fg("muted", formatPathForFooter(ctx.cwd, config.pathMaxSegments));
					const left = leftLine || fallback;
					const model = buildModelText(ctx, theme);
					const leftGroup = model ? `${left} ${model}` : left;
					const right = buildRightSide(ctx, theme, footerData);

					if (!right) return [truncateToWidth(leftGroup, width, "…")];

					const leftWidth = visibleWidth(leftGroup);
					const rightWidth = visibleWidth(right);
					if (leftWidth + rightWidth + 1 <= width) {
						return [leftGroup + " ".repeat(width - leftWidth - rightWidth) + right];
					}

					const availableLeft = Math.max(0, width - rightWidth - 1);
					if (availableLeft <= 0) return [truncateToWidth(right, width, "…")];
					return [truncateToWidth(leftGroup, availableLeft, "…") + " " + right];
				},
			};
		});

		void refreshLeft(ctx);
	}

	function restartRefreshTimer(ctx: ExtensionContext): void {
		if (refreshTimer) clearInterval(refreshTimer);
		refreshTimer = undefined;
		if (!ctx.hasUI || !config.enabled || config.refreshIntervalMs === 0) return;

		refreshTimer = setInterval(() => {
			void refreshLeft(ctx);
		}, config.refreshIntervalMs);
		refreshTimer.unref();
	}

	function persistAndApply(ctx: ExtensionContext): void {
		saveConfig(config);
		applyTheme(ctx);
		installFooter(ctx);
		restartRefreshTimer(ctx);
		void refreshLeft(ctx);
		requestRender?.();
	}

	async function pickThemePreset(ctx: ExtensionContext): Promise<void> {
		const piThemes = ctx.ui.getAllThemes().map((theme) => `pi:${theme.name}`);
		const choices = [...EXTENSION_PRESETS, ...piThemes];
		const choice = await ctx.ui.select("Starshipline theme preset", choices);
		if (!choice || !isKnownThemePreset(choice)) return;

		config = { ...config, themePreset: choice };
		persistAndApply(ctx);
		ctx.ui.notify(`Starshipline theme: ${choice}`, "info");
	}

	async function setColorOverride(ctx: ExtensionContext): Promise<void> {
		if (config.themePreset.startsWith("pi:")) {
			ctx.ui.notify("Color overrides apply to Starshipline presets, not built-in Pi themes.", "warning");
			return;
		}

		const token = await ctx.ui.select("Theme color token", COMMON_COLOR_TOKENS);
		if (!token) return;

		const current = config.colorOverrides[token] === undefined ? "preset" : String(config.colorOverrides[token]);
		const value = await ctx.ui.input(`Set ${token}`, `#RRGGBB, 0-255, or default to clear (current: ${current})`);
		if (value === undefined) return;

		const parsed = parseThemeValue(value);
		if (parsed === undefined) {
			ctx.ui.notify("Use #RRGGBB, a 0-255 xterm color, or default/blank to clear.", "error");
			return;
		}

		const colorOverrides = { ...config.colorOverrides };
		if (parsed === "") delete colorOverrides[token];
		else colorOverrides[token] = parsed;

		config = { ...config, colorOverrides };
		persistAndApply(ctx);
		ctx.ui.notify(parsed === "" ? `Cleared ${token}` : `Set ${token} = ${parsed}`, "info");
	}

	async function setStarshipConfigPath(ctx: ExtensionContext): Promise<void> {
		const value = await ctx.ui.input("Starship config path", config.starshipConfig);
		if (!value?.trim()) return;
		config = { ...config, starshipConfig: value.trim() };
		persistAndApply(ctx);
		ctx.ui.notify(`Starship config: ${value.trim()}`, "info");
	}

	async function setPathSegments(ctx: ExtensionContext): Promise<void> {
		const value = await ctx.ui.input("Path max segments", String(config.pathMaxSegments));
		if (!value?.trim()) return;
		const next = Number(value);
		if (!Number.isFinite(next) || next < 3) {
			ctx.ui.notify("Use a number >= 3", "error");
			return;
		}
		config = { ...config, pathMaxSegments: Math.round(next) };
		persistAndApply(ctx);
	}

	async function showMenu(ctx: ExtensionContext): Promise<void> {
		const action = await ctx.ui.select("Starshipline", [
			`Toggle footer (${config.enabled ? "on" : "off"})`,
			`Left mode (${config.leftMode})`,
			`Path max segments (${config.pathMaxSegments})`,
			`Theme preset (${config.themePreset})`,
			"Set color override",
			"Clear color overrides",
			`Toggle context meter (${config.showContextMeter ? "on" : "off"})`,
			`Toggle cache efficiency (${config.showCacheEfficiency ? "on" : "off"})`,
			`Toggle cache totals (${config.showCacheTotals ? "on" : "off"})`,
			`Toggle Pi stats (${config.showPiStats ? "on" : "off"})`,
			`Toggle model (${config.showModel ? "on" : "off"})`,
			`Toggle thinking (${config.showThinkingLevel ? "on" : "off"})`,
			`Toggle prompt character (${config.stripPromptCharacter ? "hidden" : "shown"})`,
			`Starship config (${config.starshipConfig})`,
			"Refresh footer",
			`Config file (${CONFIG_PATH})`,
		]);

		if (!action) return;
		if (action.startsWith("Toggle footer")) {
			config = { ...config, enabled: !config.enabled };
			persistAndApply(ctx);
			ctx.ui.notify(`Starshipline footer ${config.enabled ? "enabled" : "disabled"}`, "info");
		} else if (action.startsWith("Left mode")) {
			config = { ...config, leftMode: config.leftMode === "clean" ? "starship" : "clean" };
			persistAndApply(ctx);
		} else if (action.startsWith("Path max segments")) {
			await setPathSegments(ctx);
		} else if (action.startsWith("Theme preset")) {
			await pickThemePreset(ctx);
		} else if (action === "Set color override") {
			await setColorOverride(ctx);
		} else if (action === "Clear color overrides") {
			config = { ...config, colorOverrides: {} };
			persistAndApply(ctx);
			ctx.ui.notify("Starshipline color overrides cleared", "info");
		} else if (action.startsWith("Toggle context meter")) {
			config = { ...config, showContextMeter: !config.showContextMeter };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle cache efficiency")) {
			config = { ...config, showCacheEfficiency: !config.showCacheEfficiency };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle cache totals")) {
			config = { ...config, showCacheTotals: !config.showCacheTotals };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle Pi stats")) {
			config = { ...config, showPiStats: !config.showPiStats };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle model")) {
			config = { ...config, showModel: !config.showModel };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle thinking")) {
			config = { ...config, showThinkingLevel: !config.showThinkingLevel };
			persistAndApply(ctx);
		} else if (action.startsWith("Toggle prompt character")) {
			config = { ...config, stripPromptCharacter: !config.stripPromptCharacter };
			persistAndApply(ctx);
		} else if (action.startsWith("Starship config")) {
			await setStarshipConfigPath(ctx);
		} else if (action === "Refresh footer") {
			await refreshLeft(ctx);
			ctx.ui.notify(leftError ? `Refresh failed: ${leftError}` : "Starshipline refreshed", leftError ? "warning" : "info");
		} else if (action.startsWith("Config file")) {
			ctx.ui.notify(CONFIG_PATH, "info");
		}
	}

	function showHelp(): void {
		pi.sendMessage({
			customType: "starshipline",
			display: true,
			content: [
				"Starshipline commands:",
				"/starshipline                          open interactive menu",
				"/starshipline on|off|toggle            control footer",
				"/starshipline left clean|starship      clean path/git footer or raw Starship prompt",
				"/starshipline path-segments <n>        set clean path truncation length",
				"/starshipline theme [name]             pick/apply theme preset",
				"/starshipline color [token] [value]    set #RRGGBB or 0-255 override",
				"/starshipline clear-colors             clear overrides",
				"/starshipline context-meter on|off     toggle ctx pressure bar",
				"/starshipline cache-efficiency on|off  toggle cache hit-rate display",
				"/starshipline prompt-char show|hide    show/hide trailing Starship prompt symbol in starship mode",
				"/starshipline stats on|off             show/hide context/tokens/cache/cost",
				"/starshipline model on|off             show/hide model name",
				"/starshipline thinking on|off          show/hide thinking level",
				"/starshipline refresh                  rerender footer",
				`Config: ${CONFIG_PATH}`,
			].join("\n"),
		});
	}

	function parseOnOff(value: string | undefined, current: boolean): boolean {
		if (value === "on") return true;
		if (value === "off") return false;
		return !current;
	}

	async function handleCommand(args: string | undefined, ctx: ExtensionContext): Promise<void> {
		const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
		const [command, ...rest] = parts;

		if (!command) {
			await showMenu(ctx);
			return;
		}

		if (command === "help") {
			showHelp();
			return;
		}

		if (["on", "off", "toggle"].includes(command)) {
			config = { ...config, enabled: command === "toggle" ? !config.enabled : command === "on" };
			persistAndApply(ctx);
			ctx.ui.notify(`Starshipline footer ${config.enabled ? "enabled" : "disabled"}`, "info");
			return;
		}

		if (command === "left") {
			const mode = rest[0];
			if (mode !== "clean" && mode !== "starship") {
				ctx.ui.notify("Use /starshipline left clean|starship", "error");
				return;
			}
			config = { ...config, leftMode: mode };
			persistAndApply(ctx);
			return;
		}

		if (command === "path-segments") {
			const next = Number(rest[0]);
			if (!Number.isFinite(next) || next < 3) {
				await setPathSegments(ctx);
				return;
			}
			config = { ...config, pathMaxSegments: Math.round(next) };
			persistAndApply(ctx);
			return;
		}

		if (command === "theme") {
			const preset = rest[0];
			if (!preset) {
				await pickThemePreset(ctx);
				return;
			}

			const normalizedPreset = isKnownThemePreset(preset) ? preset : ctx.ui.getTheme(preset) ? `pi:${preset}` : undefined;
			if (!normalizedPreset) {
				ctx.ui.notify(`Unknown theme preset: ${preset}`, "error");
				return;
			}
			config = { ...config, themePreset: normalizedPreset };
			persistAndApply(ctx);
			ctx.ui.notify(`Starshipline theme: ${normalizedPreset}`, "info");
			return;
		}

		if (command === "color") {
			if (config.themePreset.startsWith("pi:")) {
				ctx.ui.notify("Color overrides apply to Starshipline presets, not built-in Pi themes.", "warning");
				return;
			}

			const [token, ...valueParts] = rest;
			if (!token || valueParts.length === 0) {
				await setColorOverride(ctx);
				return;
			}

			if (!isFgToken(token) && !isBgToken(token)) {
				ctx.ui.notify(`Unknown theme token: ${token}`, "error");
				return;
			}

			const parsed = parseThemeValue(valueParts.join(" "));
			if (parsed === undefined) {
				ctx.ui.notify("Use #RRGGBB, a 0-255 xterm color, or default/blank to clear.", "error");
				return;
			}

			const colorOverrides = { ...config.colorOverrides };
			if (parsed === "") delete colorOverrides[token];
			else colorOverrides[token] = parsed;
			config = { ...config, colorOverrides };
			persistAndApply(ctx);
			return;
		}

		if (command === "clear-colors") {
			config = { ...config, colorOverrides: {} };
			persistAndApply(ctx);
			ctx.ui.notify("Starshipline color overrides cleared", "info");
			return;
		}

		if (command === "prompt-char") {
			const mode = rest[0];
			if (mode === "show") config = { ...config, stripPromptCharacter: false };
			else if (mode === "hide") config = { ...config, stripPromptCharacter: true };
			else config = { ...config, stripPromptCharacter: !config.stripPromptCharacter };
			persistAndApply(ctx);
			return;
		}

		if (command === "stats") {
			config = { ...config, showPiStats: parseOnOff(rest[0], config.showPiStats) };
			persistAndApply(ctx);
			return;
		}

		if (command === "context-meter") {
			config = { ...config, showContextMeter: parseOnOff(rest[0], config.showContextMeter) };
			persistAndApply(ctx);
			return;
		}

		if (command === "cache-efficiency") {
			config = { ...config, showCacheEfficiency: parseOnOff(rest[0], config.showCacheEfficiency) };
			persistAndApply(ctx);
			return;
		}

		if (command === "cache-totals") {
			config = { ...config, showCacheTotals: parseOnOff(rest[0], config.showCacheTotals) };
			persistAndApply(ctx);
			return;
		}

		if (command === "model") {
			config = { ...config, showModel: parseOnOff(rest[0], config.showModel) };
			persistAndApply(ctx);
			return;
		}

		if (command === "thinking") {
			config = { ...config, showThinkingLevel: parseOnOff(rest[0], config.showThinkingLevel) };
			persistAndApply(ctx);
			return;
		}

		if (command === "config") {
			await setStarshipConfigPath(ctx);
			return;
		}

		if (command === "refresh") {
			await refreshLeft(ctx);
			ctx.ui.notify(leftError ? `Refresh failed: ${leftError}` : "Starshipline refreshed", leftError ? "warning" : "info");
			return;
		}

		showHelp();
	}

	pi.registerCommand("starshipline", {
		description: "Starship-backed footer and live theme controls",
		handler: handleCommand,
	});

	pi.on("session_start", async (_event, ctx) => {
		config = loadConfig();
		applyTheme(ctx);
		installFooter(ctx);
		restartRefreshTimer(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!config.enabled) return;
		await refreshLeft(ctx);
		requestRender?.();
	});

	pi.on("model_select", async () => {
		requestRender?.();
	});

	pi.on("thinking_level_select", async () => {
		requestRender?.();
	});

	pi.on("session_shutdown", () => {
		if (refreshTimer) clearInterval(refreshTimer);
		refreshTimer = undefined;
		requestRender = undefined;
	});
}
