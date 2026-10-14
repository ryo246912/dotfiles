// hunk の files pane を tree / flat で切り替えられる版に置き換える拡張
//
// 組み込みの files pane は pane 幅 (34列以上で tree) で表示が自動で決まり、
// 手動で切り替える手段が無い。この拡張は組み込み pane (hunk:files) を置き換え、
// `S` キー (コマンド id: files-mode.toggle) で tree / flat を切り替えられるようにする。
//
// `F` キー (コマンド id: files-mode.focus) で一覧にフォーカスし、キーボードで操作できる:
//   j / k (↓ / ↑)   行を移動 (ファイル行に乗ると diff もそのファイルへ移動)
//   g / G           先頭 / 末尾へ
//   l (→)           ディレクトリを開く (開いていれば最初の子へ)
//   h (←)           ディレクトリを閉じる (閉じていれば・ファイル上なら親ディレクトリへ)
//   Enter           ディレクトリなら開閉、ファイルならフォーカスを抜けて diff に戻る
//   Esc / F         フォーカスを抜ける
//   それ以外のキーは通常どおり hunk に渡す (q で終了など)
//
// 初期モードは ~/.config/hunk/config.toml で変更できる:
//   [extension.files-mode]
//   default = "tree"  # "tree" | "flat" | "auto"(組み込みと同じく幅で自動判定)
//
// 行の描画は組み込み pane (hunk v0.23.0 の FileSidebars.tsx / FileListItem.tsx) に揃えている。
import type { ScrollBoxRenderable } from "@opentui/core";
import { useEffect, useMemo, useRef, useSyncExternalStore, type ReactNode } from "react";
import type {
  ExtensionDiffFile,
  ExtensionKeyEvent,
  ExtensionKeyboardModeKeyResult,
  ExtensionPaneProps,
  ExtensionPaneTheme,
  HunkExtensionAPI,
} from "hunkdiff/extension";

type Mode = "tree" | "flat" | "auto";

// 組み込みと同じ閾値: 本文幅が32列以上なら auto は tree になる
const TREE_MIN_CONTENT_WIDTH = 32;

// ---- 状態の保持 ----
// キーボードモード (React の外) と pane の両方から触るため、React の外に持つ。
// pane を閉じても表示モードや折りたたみ状態が残る。

type Store = {
  mode: Mode;
  // tree 表示で折りたたんでいるディレクトリのパス
  collapsed: ReadonlySet<string>;
  // キーボードで一覧を操作中か
  focused: boolean;
  // フォーカス中のカーソル行 (rowKey)
  cursor: string | null;
};

let store: Store = { mode: "tree", collapsed: new Set(), focused: false, cursor: null };
// auto のときに実際に表示しているモード (トグル時の基準にする)
let lastResolvedMode: Exclude<Mode, "auto"> = "tree";
const listeners = new Set<() => void>();

function updateStore(update: (current: Store) => Store) {
  const next = update(store);
  if (next === store) return;
  store = next;
  for (const listener of listeners) listener();
}

function useStore() {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => store,
  );
}

function toggleCollapsed(path: string) {
  updateStore((current) => {
    const collapsed = new Set(current.collapsed);
    if (!collapsed.delete(path)) collapsed.add(path);
    return { ...current, collapsed };
  });
}

function setCollapsed(path: string, value: boolean) {
  if (store.collapsed.has(path) === value) return;
  toggleCollapsed(path);
}

// キーボードモードから見える pane の最新状態 (描画のたびに pane が書き込む)
type NavRow = {
  key: string;
  kind: "file" | "directory";
  fileId?: string;
  path?: string;
  parentKey: string | null;
};
let paneLink: {
  rows: NavRow[];
  selectedFileId: string | null;
  selectFile: (fileId: string) => void;
} | null = null;

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

const fileKey = (fileId: string) => `f:${fileId}`;
const directoryKey = (path: string) => `d:${path}`;
const rowId = (key: string) => `files-mode-row:${key}`;

// 表示中の行から、キーボードで移動できる行 (ファイル・ディレクトリ) を親子関係つきで取り出す
function buildNavRows(entries: readonly Entry[]): NavRow[] {
  const rows: NavRow[] = [];
  const directoryStack: DirectoryEntry[] = [];
  for (const entry of entries) {
    if (entry.kind === "group") continue;
    while (
      directoryStack.length > 0 &&
      directoryStack[directoryStack.length - 1].depth >= entry.depth
    ) {
      directoryStack.pop();
    }
    const parent = directoryStack[directoryStack.length - 1];
    const parentKey = parent ? directoryKey(parent.path) : null;
    if (entry.kind === "directory") {
      rows.push({ key: directoryKey(entry.path), kind: "directory", path: entry.path, parentKey });
      directoryStack.push(entry);
    } else {
      rows.push({ key: fileKey(entry.id), kind: "file", fileId: entry.id, parentKey });
    }
  }
  return rows;
}

// カーソル行の背景 (フォーカス中のみ)
function rowBackground(theme: ExtensionPaneTheme, cursor: boolean, selected = false) {
  if (cursor) return theme.selectedHunk;
  return selected ? theme.panelAlt : theme.panel;
}

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
  cursor,
  statsLaneWidth,
  textWidth,
  theme,
  onToggle,
}: {
  entry: DirectoryEntry;
  collapsed: boolean;
  cursor: boolean;
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
  const background = rowBackground(theme, cursor);
  return (
    <box
      id={rowId(directoryKey(entry.path))}
      style={{ width: "100%", height: 1, flexDirection: "row", backgroundColor: background }}
      onMouseUp={() => onToggle(entry.path)}
    >
      <text fg={cursor ? theme.accent : background} bg={background}>
        {cursor ? "▌" : " "}
      </text>
      <box
        style={{
          flexGrow: 1,
          height: 1,
          paddingLeft: indent,
          flexDirection: "row",
          backgroundColor: background,
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
              backgroundColor: background,
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
  cursor,
  paddingLeft,
  selected,
  statsLaneWidth,
  textWidth,
  theme,
  onSelect,
}: {
  entry: FileEntry;
  cursor: boolean;
  paddingLeft: number;
  selected: boolean;
  statsLaneWidth: number;
  textWidth: number;
  theme: ExtensionPaneTheme;
  onSelect: (fileId: string) => void;
}) {
  const background = rowBackground(theme, cursor, selected);
  const iconWidth = entry.icon ? 2 : 0;
  const indent = indentWidth(entry.depth, textWidth, iconWidth + statsLaneWidth + 1);
  const nameWidth = Math.max(1, textWidth - 1 - iconWidth - statsLaneWidth - indent);
  const statColor = { note: theme.noteBorder, add: theme.badgeAdded, del: theme.badgeRemoved };
  return (
    <box
      id={rowId(fileKey(entry.id))}
      style={{ width: "100%", height: 1, flexDirection: "row", backgroundColor: background }}
      onMouseUp={() => onSelect(entry.id)}
    >
      <text fg={selected || cursor ? theme.accent : background} bg={background}>
        {selected || cursor ? "▌" : " "}
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
  const { mode: currentMode, collapsed, focused, cursor } = useStore();
  const scrollRef = useRef<ScrollBoxRenderable | null>(null);
  const skipRevealRef = useRef(false);

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

  const navRows = useMemo(() => buildNavRows(entries), [entries]);
  paneLink = { rows: navRows, selectedFileId, selectFile: actions.selectFile };

  const toggleDirectory = (path: string) => {
    skipRevealRef.current = true;
    toggleCollapsed(path);
  };

  // 選択されたファイルが折りたたみの中にあれば展開し、カーソルもそのファイルに合わせる
  // (フォーカス中にカーソルがディレクトリ上にあるときは動かさない)
  useEffect(() => {
    const selected = files.find((file) => file.id === selectedFileId);
    if (!selected) return;
    updateStore((current) => {
      const hidden = directoryPaths(selected.path).filter((path) => current.collapsed.has(path));
      const keepCursor = current.focused && current.cursor?.startsWith("d:");
      const nextCursor = keepCursor ? current.cursor : fileKey(selected.id);
      if (hidden.length === 0 && nextCursor === current.cursor) return current;
      const collapsed = new Set(current.collapsed);
      for (const path of hidden) collapsed.delete(path);
      return { ...current, collapsed, cursor: nextCursor };
    });
  }, [files, selectedFileId]);

  // フォーカス中はカーソル行、それ以外は選択行を表示範囲に入れる (マウスでの開閉直後は除く)
  useEffect(() => {
    if (skipRevealRef.current) {
      skipRevealRef.current = false;
      return;
    }
    const key = focused ? cursor : selectedFileId ? fileKey(selectedFileId) : null;
    if (key) scrollRef.current?.scrollChildIntoView(rowId(key));
  }, [collapsed, cursor, files, focused, resolvedMode, selectedFileId]);

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
                cursor={focused && cursor === directoryKey(entry.path)}
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
              cursor={focused && cursor === fileKey(entry.id)}
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
    store = { ...store, mode: configured };
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
    const current = store.mode === "auto" ? lastResolvedMode : store.mode;
    const next = current === "tree" ? "flat" : "tree";
    updateStore((state) => ({ ...state, mode: next }));
    if (!ctx.panes.isOpen("files")) ctx.panes.open("files");
    ctx.notify(`Files: ${next}`);
  });

  hunk.registerKeyboardMode({
    id: "focus",
    title: "Files",
    onEnter() {
      const selected = paneLink?.selectedFileId;
      updateStore((state) => ({
        ...state,
        focused: true,
        cursor: selected ? fileKey(selected) : (paneLink?.rows[0]?.key ?? null),
      }));
    },
    onExit() {
      updateStore((state) => ({ ...state, focused: false }));
    },
    onKey(key) {
      return handleFocusKey(key);
    },
  });

  hunk.registerCommand({ id: "focus", title: "Focus files pane", key: "F" }, (ctx) => {
    if (ctx.keyboardModes.isActive("focus")) {
      ctx.keyboardModes.exitMode();
      return;
    }
    if (!ctx.panes.isOpen("files")) ctx.panes.open("files");
    ctx.keyboardModes.enterMode("focus");
  });
}

// ---- フォーカス中のキー操作 ----

function isChar(key: ExtensionKeyEvent, char: string) {
  return key.sequence === char;
}

function moveCursor(rows: readonly NavRow[], index: number) {
  const row = rows[Math.max(0, Math.min(rows.length - 1, index))];
  if (!row) return;
  updateStore((state) => (state.cursor === row.key ? state : { ...state, cursor: row.key }));
  if (row.kind === "file" && row.fileId && row.fileId !== paneLink?.selectedFileId) {
    paneLink?.selectFile(row.fileId);
  }
}

function handleFocusKey(key: ExtensionKeyEvent): ExtensionKeyboardModeKeyResult {
  if (key.ctrl || key.meta || key.option) return "pass";
  if (key.name === "escape" || isChar(key, "F")) return "exit";

  const rows = paneLink?.rows ?? [];
  if (rows.length === 0) return "pass";
  const index = rows.findIndex((row) => row.key === store.cursor);
  const row = rows[index];

  if (key.name === "down" || isChar(key, "j")) {
    moveCursor(rows, index < 0 ? 0 : index + 1);
    return "handled";
  }
  if (key.name === "up" || isChar(key, "k")) {
    moveCursor(rows, index < 0 ? 0 : index - 1);
    return "handled";
  }
  if (isChar(key, "g") || key.name === "home") {
    moveCursor(rows, 0);
    return "handled";
  }
  if (isChar(key, "G") || key.name === "end") {
    moveCursor(rows, rows.length - 1);
    return "handled";
  }
  if (!row) return "pass";

  if (key.name === "right" || isChar(key, "l")) {
    if (row.kind === "directory" && row.path) {
      if (store.collapsed.has(row.path)) setCollapsed(row.path, false);
      else moveCursor(rows, index + 1);
    }
    return "handled";
  }
  if (key.name === "left" || isChar(key, "h")) {
    if (row.kind === "directory" && row.path && !store.collapsed.has(row.path)) {
      setCollapsed(row.path, true);
    } else if (row.parentKey) {
      moveCursor(
        rows,
        rows.findIndex((candidate) => candidate.key === row.parentKey),
      );
    }
    return "handled";
  }
  if (key.name === "return" || key.name === "enter") {
    if (row.kind === "directory" && row.path) {
      toggleCollapsed(row.path);
      return "handled";
    }
    return "exit";
  }
  return "pass";
}
