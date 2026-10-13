// hunk の files pane を tree / flat で切り替えられる版に置き換える拡張
//
// 組み込みの files pane は pane 幅 (34列以上で tree) で表示が自動で決まり、
// 手動で切り替える手段が無い。この拡張は組み込み pane (hunk:files) を置き換え、
// `S` キー (コマンド id: files-mode.toggle) で tree / flat を切り替えられるようにする。
//
// 初期モードは ~/.config/hunk/config.toml で変更できる:
//   [extension.files-mode]
//   default = "tree"  # "tree" | "flat" | "auto"(組み込みと同じく幅で自動判定)
//
// 行の描画は組み込み pane (hunk v0.23.0 の FileSidebars.tsx / FileListItem.tsx) に揃えている。
import type { ScrollBoxRenderable } from "@opentui/core";
import { useEffect, useMemo, useRef, useState, useSyncExternalStore, type ReactNode } from "react";
import type {
  ExtensionDiffFile,
  ExtensionPaneProps,
  ExtensionPaneTheme,
  HunkExtensionAPI,
} from "hunkdiff/extension";

type Mode = "tree" | "flat" | "auto";

// 組み込みと同じ閾値: 本文幅が32列以上なら auto は tree になる
const TREE_MIN_CONTENT_WIDTH = 32;

// ---- モードの保持 (pane を閉じても状態が残るよう React の外に持つ) ----

let mode: Mode = "tree";
// auto のときに実際に表示しているモード (トグル時の基準にする)
let lastResolvedMode: Exclude<Mode, "auto"> = "tree";
const listeners = new Set<() => void>();

function setMode(next: Mode) {
  if (next === mode) return;
  mode = next;
  for (const listener of listeners) listener();
}

function useMode() {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => mode,
  );
}

// ---- 表示用のエントリ構築 ----

type FileEntry = {
  kind: "file";
  id: string;
  name: string;
  depth: number;
  stats: { kind: "note" | "add" | "del"; text: string }[];
  icon: { text: string; color: keyof ExtensionPaneTheme } | null;
};
type GroupEntry = { kind: "group"; id: string; label: string };
type DirectoryEntry = {
  kind: "directory";
  id: string;
  path: string;
  label: string;
  depth: number;
  fileCount: number;
};
type Entry = FileEntry | GroupEntry | DirectoryEntry;

function dirname(path: string) {
  const index = path.lastIndexOf("/");
  if (index < 0) return ".";
  if (index === 0) return "/";
  return path.slice(0, index);
}

function basename(path: string) {
  return path.slice(path.lastIndexOf("/") + 1);
}

function fileName(file: ExtensionDiffFile) {
  const name = basename(file.path);
  if (!file.previousPath || file.previousPath === file.path) return name;
  const previousName = basename(file.previousPath);
  return previousName === name ? name : `${previousName} -> ${name}`;
}

function fileIcon(file: ExtensionDiffFile): FileEntry["icon"] {
  if (file.isUntracked) return { text: "?", color: "fileUntracked" };
  switch (file.changeType ?? "change") {
    case "new":
      return { text: "A", color: "fileNew" };
    case "deleted":
      return { text: "D", color: "fileDeleted" };
    case "rename-pure":
    case "rename-changed":
      return { text: "R", color: "fileRenamed" };
    case "change":
      return { text: "M", color: "fileModified" };
    default:
      return null;
  }
}

function fileEntry(file: ExtensionDiffFile, depth: number): FileEntry {
  const stats: FileEntry["stats"] = [];
  const notes = file.agent?.annotations.length ?? 0;
  if (notes > 0) stats.push({ kind: "note", text: `*${notes}` });
  if (file.stats.additions > 0) {
    stats.push({ kind: "add", text: `+${file.stats.additions}${file.statsTruncated ? "+" : ""}` });
  }
  if (file.stats.deletions > 0) stats.push({ kind: "del", text: `-${file.stats.deletions}` });
  return { kind: "file", id: file.id, name: fileName(file), depth, stats, icon: fileIcon(file) };
}

function statsWidth(entry: FileEntry) {
  return entry.stats.reduce(
    (width, stat, index) => width + stat.text.length + (index > 0 ? 1 : 0),
    0,
  );
}

// flat: ディレクトリ見出しの下にファイル名を並べる
function buildFlatEntries(files: readonly ExtensionDiffFile[]): Entry[] {
  const entries: Entry[] = [];
  let activeGroup: string | undefined;
  files.forEach((file, index) => {
    const group = dirname(file.path);
    if (group !== activeGroup) {
      activeGroup = group;
      entries.push({
        kind: "group",
        id: `group:${group}:${index}`,
        label: group === "." ? "./" : `${group}/`,
      });
    }
    entries.push(fileEntry(file, 0));
  });
  return entries;
}

function directorySegments(parent: string) {
  if (parent === ".") return [];
  const root = parent.match(/^\/+/u)?.[0];
  const segments = parent.split("/").filter(Boolean);
  return root ? [root, ...segments] : segments;
}

function directoryPath(segments: readonly string[]) {
  const [root, ...rest] = segments;
  return root?.startsWith("/") ? `${root}${rest.join("/")}` : segments.join("/");
}

function directoryPaths(path: string) {
  const segments = directorySegments(dirname(path));
  return segments.map((_, depth) => directoryPath(segments.slice(0, depth + 1)));
}

// tree: ディレクトリ階層をインデントで表示する (レビュー順は保つ)
function buildTreeEntries(files: readonly ExtensionDiffFile[]): Entry[] {
  const entries: Entry[] = [];
  let activeSegments: string[] = [];
  let activeDirectories: DirectoryEntry[] = [];
  files.forEach((file, fileIndex) => {
    const segments = directorySegments(dirname(file.path));
    let shared = 0;
    while (
      shared < Math.min(activeSegments.length, segments.length) &&
      activeSegments[shared] === segments[shared]
    ) {
      shared += 1;
    }
    activeDirectories = activeDirectories.slice(0, shared);
    for (let depth = shared; depth < segments.length; depth += 1) {
      const segment = segments[depth];
      const path = directoryPath(segments.slice(0, depth + 1));
      const directory: DirectoryEntry = {
        kind: "directory",
        id: `directory:${fileIndex}:${depth}:${path}`,
        path,
        label: segment.startsWith("/") ? segment : `${segment}/`,
        depth,
        fileCount: 0,
      };
      entries.push(directory);
      activeDirectories.push(directory);
    }
    entries.push(fileEntry(file, segments.length));
    for (const directory of activeDirectories) directory.fileCount += 1;
    activeSegments = segments;
  });
  return entries;
}

// 折りたたまれたディレクトリの子孫を隠す
function collapseEntries(entries: readonly Entry[], collapsed: ReadonlySet<string>): Entry[] {
  if (collapsed.size === 0) return [...entries];
  const visible: Entry[] = [];
  let collapsedDepth: number | null = null;
  for (const entry of entries) {
    if (entry.kind === "group") {
      collapsedDepth = null;
      visible.push(entry);
      continue;
    }
    if (collapsedDepth !== null) {
      if (entry.depth > collapsedDepth) continue;
      collapsedDepth = null;
    }
    visible.push(entry);
    if (entry.kind === "directory" && collapsed.has(entry.path)) collapsedDepth = entry.depth;
  }
  return visible;
}

// ---- テキスト幅 ----

function textWidthOf(text: string) {
  const bun = (globalThis as { Bun?: { stringWidth?: (s: string) => number } }).Bun;
  return bun?.stringWidth ? bun.stringWidth(text) : text.length;
}

function fitText(text: string, width: number, marker = ".") {
  if (width <= 0) return "";
  if (textWidthOf(text) <= width) return text;
  let result = "";
  for (const char of text) {
    if (textWidthOf(result + char) > width - marker.length) break;
    result += char;
  }
  return `${result}${marker}`;
}

function padText(text: string, width: number) {
  const fitted = fitText(text, width);
  return `${fitted}${" ".repeat(Math.max(0, width - textWidthOf(fitted)))}`;
}

function indentWidth(depth: number, textWidth: number, reserved: number) {
  return Math.min(Math.max(0, depth) * 2, Math.max(0, textWidth - reserved - 1));
}

const rowId = (fileId: string) => `files-mode-row:${fileId}`;

// ---- 行コンポーネント ----

function GroupRow({
  entry,
  textWidth,
  theme,
}: {
  entry: GroupEntry;
  textWidth: number;
  theme: ExtensionPaneTheme;
}) {
  return (
    <box style={{ width: "100%", height: 1, paddingLeft: 1, backgroundColor: theme.panel }}>
      <text fg={theme.muted}>{fitText(entry.label, Math.max(1, textWidth))}</text>
    </box>
  );
}

function DirectoryRow({
  entry,
  collapsed,
  statsLaneWidth,
  textWidth,
  theme,
  onToggle,
}: {
  entry: DirectoryEntry;
  collapsed: boolean;
  statsLaneWidth: number;
  textWidth: number;
  theme: ExtensionPaneTheme;
  onToggle: (path: string) => void;
}) {
  const countText = collapsed
    ? `${entry.fileCount} ${entry.fileCount === 1 ? "file" : "files"}`
    : null;
  const trailingWidth = countText ? Math.max(statsLaneWidth, countText.length + 1) : 0;
  const indent = indentWidth(entry.depth, textWidth, 2 + trailingWidth + 1);
  const labelWidth = Math.max(1, textWidth - 1 - 2 - trailingWidth - indent);
  return (
    <box
      style={{ width: "100%", height: 1, flexDirection: "row", backgroundColor: theme.panel }}
      onMouseUp={() => onToggle(entry.path)}
    >
      <box style={{ width: 1, height: 1, backgroundColor: theme.panel }} />
      <box
        style={{
          flexGrow: 1,
          height: 1,
          paddingLeft: indent,
          flexDirection: "row",
          backgroundColor: theme.panel,
        }}
      >
        <text fg={theme.muted}>{collapsed ? "› " : "⌄ "}</text>
        <text fg={theme.muted}>{padText(fitText(entry.label, labelWidth), labelWidth)}</text>
        {countText && (
          <box
            style={{
              width: trailingWidth,
              height: 1,
              flexDirection: "row",
              justifyContent: "flex-end",
              backgroundColor: theme.panel,
            }}
          >
            <text fg={theme.muted}>{countText}</text>
          </box>
        )}
      </box>
    </box>
  );
}

function FileRow({
  entry,
  paddingLeft,
  selected,
  statsLaneWidth,
  textWidth,
  theme,
  onSelect,
}: {
  entry: FileEntry;
  paddingLeft: number;
  selected: boolean;
  statsLaneWidth: number;
  textWidth: number;
  theme: ExtensionPaneTheme;
  onSelect: (fileId: string) => void;
}) {
  const background = selected ? theme.panelAlt : theme.panel;
  const iconWidth = entry.icon ? 2 : 0;
  const indent = indentWidth(entry.depth, textWidth, iconWidth + statsLaneWidth + 1);
  const nameWidth = Math.max(1, textWidth - 1 - iconWidth - statsLaneWidth - indent);
  const statColor = { note: theme.noteBorder, add: theme.badgeAdded, del: theme.badgeRemoved };
  return (
    <box
      id={rowId(entry.id)}
      style={{ width: "100%", height: 1, flexDirection: "row", backgroundColor: background }}
      onMouseUp={() => onSelect(entry.id)}
    >
      <text fg={selected ? theme.accent : background} bg={background}>
        {selected ? "▌" : " "}
      </text>
      <box
        style={{
          flexGrow: 1,
          height: 1,
          paddingLeft: paddingLeft + indent,
          flexDirection: "row",
          backgroundColor: background,
        }}
      >
        {entry.icon && <text fg={theme[entry.icon.color]}>{entry.icon.text} </text>}
        <text fg={theme.text}>{padText(fitText(entry.name, nameWidth, "…"), nameWidth)}</text>
        {statsLaneWidth > 0 && (
          <box
            style={{
              width: statsLaneWidth,
              height: 1,
              flexDirection: "row",
              justifyContent: "flex-end",
              backgroundColor: background,
            }}
          >
            {entry.stats.map((stat, index) => (
              <box
                key={stat.kind}
                style={{ height: 1, flexDirection: "row", backgroundColor: background }}
              >
                {index > 0 && <text fg={theme.muted}> </text>}
                <text fg={statColor[stat.kind]}>{stat.text}</text>
              </box>
            ))}
          </box>
        )}
      </box>
    </box>
  );
}

// ---- pane 本体 ----

function FilesModePane({
  files,
  selectedFileId,
  theme,
  width,
  actions,
}: ExtensionPaneProps): ReactNode {
  const currentMode = useMode();
  const scrollRef = useRef<ScrollBoxRenderable | null>(null);
  const skipRevealRef = useRef(false);
  const [collapsed, setCollapsed] = useState<ReadonlySet<string>>(() => new Set());

  // 組み込みと同じく、行頭の選択マーカー1列 + 余白を引いた幅をテキスト幅とする
  const textWidth = Math.max(8, width - 2);
  const resolvedMode =
    currentMode === "auto" ? (textWidth >= TREE_MIN_CONTENT_WIDTH ? "tree" : "flat") : currentMode;
  lastResolvedMode = resolvedMode;

  const entries = useMemo(
    () =>
      resolvedMode === "tree"
        ? collapseEntries(buildTreeEntries(files), collapsed)
        : buildFlatEntries(files),
    [files, collapsed, resolvedMode],
  );
  const fileEntries = entries.filter((entry): entry is FileEntry => entry.kind === "file");
  const maxStats = Math.max(0, ...fileEntries.map(statsWidth));
  const statsLaneWidth = maxStats > 0 ? maxStats + 1 : 0;

  const toggleDirectory = (path: string) => {
    skipRevealRef.current = true;
    setCollapsed((current) => {
      const next = new Set(current);
      if (!next.delete(path)) next.add(path);
      return next;
    });
  };

  // 選択されたファイルが折りたたみの中にあれば展開する
  useEffect(() => {
    const selected = files.find((file) => file.id === selectedFileId);
    if (!selected) return;
    setCollapsed((current) => {
      const hidden = directoryPaths(selected.path).filter((path) => current.has(path));
      if (hidden.length === 0) return current;
      const next = new Set(current);
      for (const path of hidden) next.delete(path);
      return next;
    });
  }, [files, selectedFileId]);

  // 選択行を常に表示範囲に入れる (ディレクトリの開閉操作の直後は除く)
  useEffect(() => {
    if (skipRevealRef.current) {
      skipRevealRef.current = false;
      return;
    }
    if (selectedFileId) scrollRef.current?.scrollChildIntoView(rowId(selectedFileId));
  }, [collapsed, files, resolvedMode, selectedFileId]);

  return (
    <scrollbox
      ref={scrollRef}
      width="100%"
      height="100%"
      focused={false}
      scrollY={true}
      viewportCulling={true}
      rootOptions={{ backgroundColor: theme.panel }}
      wrapperOptions={{ backgroundColor: theme.panel }}
      viewportOptions={{ backgroundColor: theme.panel }}
      contentOptions={{ backgroundColor: theme.panel }}
      verticalScrollbarOptions={{ visible: false }}
      horizontalScrollbarOptions={{ visible: false }}
    >
      <box style={{ width: "100%", flexDirection: "column" }}>
        {entries.map((entry) => {
          if (entry.kind === "group") {
            return <GroupRow key={entry.id} entry={entry} textWidth={textWidth} theme={theme} />;
          }
          if (entry.kind === "directory") {
            return (
              <DirectoryRow
                key={entry.id}
                entry={entry}
                collapsed={collapsed.has(entry.path)}
                statsLaneWidth={statsLaneWidth}
                textWidth={textWidth}
                theme={theme}
                onToggle={toggleDirectory}
              />
            );
          }
          return (
            <FileRow
              key={entry.id}
              entry={entry}
              paddingLeft={resolvedMode === "tree" ? 0 : 1}
              selected={entry.id === selectedFileId}
              statsLaneWidth={statsLaneWidth}
              textWidth={textWidth}
              theme={theme}
              onSelect={actions.selectFile}
            />
          );
        })}
      </box>
    </scrollbox>
  );
}

export default function registerFilesMode(hunk: HunkExtensionAPI) {
  const configured = hunk.config.default;
  if (configured === "tree" || configured === "flat" || configured === "auto") {
    mode = configured;
  } else if (configured !== undefined) {
    hunk.log(`unknown default mode: ${String(configured)} (expected "tree", "flat" or "auto")`);
  }

  hunk.registerPane({
    id: "files",
    title: "Files",
    placement: "left",
    replaces: "hunk:files",
    width: { preferred: 34, min: 22, max: 56, fraction: 0.16 },
    component: FilesModePane,
  });

  hunk.registerCommand({ id: "toggle", title: "Toggle files pane tree/flat", key: "S" }, (ctx) => {
    const current = mode === "auto" ? lastResolvedMode : mode;
    const next = current === "tree" ? "flat" : "tree";
    setMode(next);
    if (!ctx.panes.isOpen("files")) ctx.panes.open("files");
    ctx.notify(`Files: ${next}`);
  });
}
