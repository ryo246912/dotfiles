#!/usr/bin/env bun

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title deepwiki
// @raycast.mode silent
//fullOutput

// Optional parameters:
// @raycast.icon 🤖
// @raycast.description GitHubのURLをDeepWikiで開く

// 対応ブラウザのバンドルID定数
const BUNDLE_ID = {
  CHROME: "com.google.Chrome",
  ARC: "company.thebrowser.Browser",
};

const { exec } = require("child_process");

// AppleScriptを実行するヘルパー関数
async function runAppleScript(script) {
  return new Promise((resolve, reject) => {
    // osascriptコマンドを使ってAppleScriptを実行
    exec(`osascript -e '${script}'`, (error, stdout, stderr) => {
      if (error) {
        // stderrもエラーメッセージに含める
        reject(new Error(`${error.message}\nStderr: ${stderr}`));
        return;
      }
      resolve(stdout.trim()); // 結果の空白を削除して返す
    });
  });
}

async function main() {
  let currentURL = "";
  let browserName = "";
  let targetBundleID = "";

  // 1. 最前面のアプリケーションのバンドルIDを取得 (AppleScript経由)
  try {
    const appInfo = await runAppleScript(`
      tell application "System Events"
        set frontmostProcess to first process whose frontmost is true
        set appName to name of frontmostProcess
        set bundleId to bundle identifier of frontmostProcess
        return appName & "|" & bundleId
      end tell
    `);
    [browserName, targetBundleID] = appInfo.split("|");
  } catch (error) {
    console.error("最前面アプリ取得エラー:", error);
    return;
  }

  let appleScriptToGetUrl = "";

  // 2. ブラウザに応じてURL取得用のAppleScriptを構築
  if (targetBundleID === BUNDLE_ID.CHROME) {
    browserName = "Google Chrome";
    appleScriptToGetUrl =
      'tell application "Google Chrome" to return URL of active tab of front window as string';
  } else if (targetBundleID === BUNDLE_ID.ARC) {
    appleScriptToGetUrl =
      'tell application "Arc" to get the URL of the active tab of front window';
  } else {
    // その他のブラウザの場合
    console.error(
      `${browserName}は非対応ブラウザです。Chrome, Arc, Safari, Edgeを使用してください。`,
    );
    return;
  }

  // 3. AppleScriptを実行してURLを取得
  try {
    if (appleScriptToGetUrl) {
      currentURL = await runAppleScript(appleScriptToGetUrl);
    }
  } catch (error) {
    console.error(
      `URLの取得に失敗しました: ${browserName}からURLを取得できませんでした。`,
      error,
    );
    return;
  }

  // 4. URLの妥当性チェックと変換
  if (!currentURL || !currentURL.includes("https://github.com/")) {
    console.error(
      "GitHubのURLではありません。現在開いているタブがGitHubのURLであることを確認してください。",
    );
    return;
  }

  const newURL = currentURL.replace(
    "https://github.com/",
    "https://deepwiki.com/",
  );

  // 5. 新しいURLを別タブで開く (AppleScript経由)
  try {
    let openTabScript = "";
    if (targetBundleID === BUNDLE_ID.CHROME) {
      openTabScript = `tell application \"Google Chrome\"
        tell front window
          set newTab to make new tab with properties {URL: \"${newURL}\"}
          set active tab index to (index of newTab)
        end tell
        activate
      end tell`;
    } else if (targetBundleID === BUNDLE_ID.ARC) {
      // Arc
      openTabScript = `tell application \"Arc\"
        tell front window
          make new tab with properties {URL: \"${newURL}\"}
        end tell
        activate
      end tell`;
    } else {
      openTabScript = `tell application \"${browserName}\" to open location \"${newURL}\"`;
    }
    await runAppleScript(openTabScript);
    console.log("DeepWikiで別タブで開きました: ", newURL);
  } catch (error) {
    console.error(`新しいURLを開けませんでした: ${error.message}`);
  }
}

main(); // スクリプトの実行を開始
