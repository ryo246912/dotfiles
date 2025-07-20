#!/bin/bash

# GitHub リポジトリの設定更新とルールセット作成を行う統合スクリプト
# 使用方法: ./setup-github.sh <owner/repository_name>

set -euo pipefail

# 固定値設定
REPO_NAME=""
OWNER=""
REPO_FULL_NAME=""

# リポジトリ設定
ALLOW_SQUASH_MERGE="true"
ALLOW_MERGE_COMMIT="true"

# ルールセット設定
RULESET_NAME="main"
ENFORCEMENT="disabled"
REF_INCLUDE=("~DEFAULT_BRANCH")
PREVENT_DELETION="true"
ALLOW_UPDATE="false"
REQUIRED_APPROVING_REVIEW_COUNT="1"
REQUIRE_LAST_PUSH_APPROVAL="true"
DISMISS_STALE_REVIEWS="true"

# ヘルプメッセージ
show_help() {
    cat << EOF
使用方法: $0 <owner/repository_name>

リポジトリとルールセットを設定します。

必須引数:
  owner/repository_name     設定を更新するリポジトリ（owner/repo形式）

設定値を変更したい場合は、スクリプト内の設定値を編集してください。

リポジトリ設定（固定）:
  スカッシュマージ許可: true
  マージコミット許可: true
  リベースマージ許可: false
  ブランチ更新許可: true
  マージ後ブランチ削除: true
  Issues機能: true
  セキュリティスキャン: enabled（可能な場合）

ルールセット設定（固定）:
  ルールセット名: main
  実行モード: disabled
  対象ブランチ: ~DEFAULT_BRANCH
  削除防止: true
  更新許可: false
  必要承認数: 1
  最新プッシュ承認要求: true
  古いレビュー却下: true

例:
  $0 username/my-repo
  $0 organization/another-repo

EOF
}

# 引数解析
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    # ヘルプオプションの確認
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi

    REPO_FULL_NAME="$1"

    # 2番目以降の引数があった場合はエラー
    if [[ $# -gt 1 ]]; then
        echo "エラー: 余分な引数が指定されています: ${@:2}" >&2
        echo "このスクリプトはowner/repository形式の引数のみを受け取ります。" >&2
        show_help
        exit 1
    fi

    # owner/repository形式の検証と分割
    if [[ ! "$REPO_FULL_NAME" =~ ^[^/]+/[^/]+$ ]]; then
        echo "エラー: リポジトリ名は 'owner/repository' の形式で指定してください。" >&2
        echo "例: username/my-repo" >&2
        show_help
        exit 1
    fi

    # ownerとrepository名を分割
    OWNER="${REPO_FULL_NAME%%/*}"
    REPO_NAME="${REPO_FULL_NAME##*/}"

    # 空の値をチェック
    if [[ -z "$OWNER" || -z "$REPO_NAME" ]]; then
        echo "エラー: owner または repository 名が空です。" >&2
        echo "正しい形式: owner/repository" >&2
        show_help
        exit 1
    fi
}

# リポジトリの存在確認（必須）
ensure_repository_exists() {
    local repo_path="$OWNER/$REPO_NAME"
    if ! gh repo view "$repo_path" &>/dev/null; then
        echo "エラー: リポジトリ '$repo_path' が見つかりません。" >&2
        echo "リポジトリが存在することを確認してください。" >&2
        exit 1
    fi
}

# リポジトリ設定更新
update_repository_settings() {
    local repo_path="$OWNER/$REPO_NAME"

    # マージ設定とその他の設定をAPI経由で更新
    echo "リポジトリ設定を更新中..."
    gh api "repos/$repo_path" --method PATCH \
        --field allow_squash_merge="$ALLOW_SQUASH_MERGE" \
        --field allow_merge_commit="$ALLOW_MERGE_COMMIT" \
        --field allow_rebase_merge=false \
        --field allow_update_branch=true \
        --field delete_branch_on_merge=true \
        --field has_issues=true \
        2>/dev/null || echo "注意: 一部の設定更新に失敗しました。権限を確認してください。"

    echo "リポジトリ '$repo_path' の設定を更新しました。"
    echo "更新された設定:"
    echo "  - スカッシュマージ許可: $ALLOW_SQUASH_MERGE"
    echo "  - マージコミット許可: $ALLOW_MERGE_COMMIT"
    echo "  - リベースマージ許可: false"
    echo "  - ブランチ更新許可: true"
    echo "  - マージ後ブランチ削除: true"
    echo "  - Issues機能: true"
}

# 真偽値の変換
bool_to_json() {
    case "$1" in
        true|True|TRUE) echo "true" ;;
        false|False|FALSE) echo "false" ;;
        *) echo "$1" ;;
    esac
}

# ref_include配列をJSON配列に変換
refs_to_json() {
    local refs=("$@")
    local json="["
    for i in "${!refs[@]}"; do
        json="$json\"${refs[i]}\""
        if [[ $i -lt $((${#refs[@]} - 1)) ]]; then
            json="$json,"
        fi
    done
    json="$json]"
    echo "$json"
}

# 既存ルールセットの確認
get_existing_ruleset_id() {
    local repo_path="$OWNER/$REPO_NAME"
    local ruleset_id

    ruleset_id=$(gh api "repos/$repo_path/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || echo "")
    echo "$ruleset_id"
}

# ルールセット作成
create_ruleset() {
    local repo_path="$OWNER/$REPO_NAME"
    echo "ルールセット '$RULESET_NAME' を作成しています..."

    local refs_json
    refs_json=$(refs_to_json "${REF_INCLUDE[@]}")

    local deletion_bool
    deletion_bool=$(bool_to_json "$PREVENT_DELETION")

    local update_bool
    update_bool=$(bool_to_json "$ALLOW_UPDATE")

    local last_push_bool
    last_push_bool=$(bool_to_json "$REQUIRE_LAST_PUSH_APPROVAL")

    local stale_reviews_bool
    stale_reviews_bool=$(bool_to_json "$DISMISS_STALE_REVIEWS")

    local ruleset_json
    read -r -d '' ruleset_json <<EOF || true
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "$ENFORCEMENT",
  "conditions": {
    "ref_name": {
      "include": $refs_json,
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "creation",
      "parameters": {}
    },
    {
      "type": "deletion",
      "parameters": {}
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "required_signatures"
    },
    {
      "type": "update",
      "parameters": {
        "update_allows_fetch_and_merge": false
      }
    },
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": $stale_reviews_bool,
        "require_code_owner_review": false,
        "require_last_push_approval": $last_push_bool,
        "required_approving_review_count": $REQUIRED_APPROVING_REVIEW_COUNT,
        "required_review_thread_resolution": false
      }
    }
  ]
}
EOF

    # ルールセット作成 API呼び出し
    gh api "repos/$repo_path/rulesets" \
        --method POST \
        --input - <<< "$ruleset_json" \
        --jq '.id' > /dev/null

    echo "ルールセット '$RULESET_NAME' を作成しました。"
}

# ルールセット更新
update_ruleset() {
    local repo_path="$OWNER/$REPO_NAME"
    local ruleset_id="$1"
    echo "ルールセット '$RULESET_NAME' (ID: $ruleset_id) を更新しています..."

    local refs_json
    refs_json=$(refs_to_json "${REF_INCLUDE[@]}")

    local deletion_bool
    deletion_bool=$(bool_to_json "$PREVENT_DELETION")

    local update_bool
    update_bool=$(bool_to_json "$ALLOW_UPDATE")

    local last_push_bool
    last_push_bool=$(bool_to_json "$REQUIRE_LAST_PUSH_APPROVAL")

    local stale_reviews_bool
    stale_reviews_bool=$(bool_to_json "$DISMISS_STALE_REVIEWS")

    local ruleset_json
    read -r -d '' ruleset_json <<EOF || true
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "$ENFORCEMENT",
  "conditions": {
    "ref_name": {
      "include": $refs_json,
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "creation",
      "parameters": {}
    },
    {
      "type": "deletion",
      "parameters": {}
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "required_signatures"
    },
    {
      "type": "update",
      "parameters": {
        "update_allows_fetch_and_merge": false
      }
    },
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": $stale_reviews_bool,
        "require_code_owner_review": false,
        "require_last_push_approval": $last_push_bool,
        "required_approving_review_count": $REQUIRED_APPROVING_REVIEW_COUNT,
        "required_review_thread_resolution": false
      }
    }
  ]
}
EOF

    # ルールセット更新 API呼び出し
    gh api "repos/$repo_path/rulesets/$ruleset_id" \
        --method PUT \
        --input - <<< "$ruleset_json" \
        --jq '.id' > /dev/null

    echo "ルールセット '$RULESET_NAME' を更新しました。"
}

# ルールセット設定処理
setup_ruleset() {
    local repo_path="$OWNER/$REPO_NAME"

    # 既存ルールセットの確認
    local existing_ruleset_id
    existing_ruleset_id=$(get_existing_ruleset_id)

    if [[ -n "$existing_ruleset_id" ]]; then
        echo "ルールセットが既に存在します。更新します。"
        update_ruleset "$existing_ruleset_id"
    else
        create_ruleset
    fi

    echo "ルールセット設定が完了しました。"
    echo "設定されたルールセット:"
    echo "  - ルールセット名: $RULESET_NAME"
    echo "  - 実行モード: $ENFORCEMENT"
    echo "  - 対象ブランチ: ${REF_INCLUDE[*]}"
    echo "  - 削除防止: $PREVENT_DELETION"
    echo "  - 更新許可: $ALLOW_UPDATE"
    echo "  - 必要承認数: $REQUIRED_APPROVING_REVIEW_COUNT"
    echo "  - 最新プッシュ承認要求: $REQUIRE_LAST_PUSH_APPROVAL"
    echo "  - 古いレビュー却下: $DISMISS_STALE_REVIEWS"
}

# メイン処理
main() {
    parse_args "$@"

    echo "=== GitHub リポジトリとルールセットの設定を開始します ==="
    echo "リポジトリ: $OWNER/$REPO_NAME"
    echo

    # リポジトリの存在確認（必須）
    ensure_repository_exists

    # ステップ1: リポジトリ設定更新
    echo "=== ステップ 1: リポジトリ設定の更新 ==="
    update_repository_settings
    echo

    # ステップ2: ルールセット設定
    echo "=== ステップ 2: ルールセットの設定 ==="
    setup_ruleset
    echo

    echo "=== 完了: すべての設定が完了しました ==="
}

# スクリプト実行
main "$@"
