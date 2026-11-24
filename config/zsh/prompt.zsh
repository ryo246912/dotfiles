# jobsの数を表示、%(1j.true.false):三項式、1j:jobs数が1以上でtrue
number_of_jobs="%(1j.%F{208}(%f%F{226}%B%j%b%F{208})%f.)"
# 終了ステータスを表示、0?:終了ステータスが0でtrue、%#:ユーザ種別
exit_status="%(0?.%F{002}.%F{001})%#%f"
# ディレクトリ表示、%F{}%f:色の指定、%B{}%b:太文字、%~:$HOMEからのパス
directory="%B%F{6}%~%f%b"
# 時刻表示、%D{format}:日付、%*:時刻(秒付)
# datetime="[%D{%m/%d} %*]"
# python、venv表示
if [ -n "$VIRTUAL_ENV" ]; then
  PYTHON_VIRTUAL_ENV="($(basename $VIRTUAL_ENV))"
else
  PYTHON_VIRTUAL_ENV=""
fi
# nix-shell表示
if [ -n "$IN_NIX_SHELL" ]; then
  IN_NIX_SHELL="[nix-shell]"
else
  IN_NIX_SHELL=""
fi
# プロンプト
MAINPROMPT="${IN_NIX_SHELL}${PYTHON_VIRTUAL_ENV}${directory}${number_of_jobs} ${exit_status} "
# プロンプトの設定
PROMPT="
${MAINPROMPT}"
