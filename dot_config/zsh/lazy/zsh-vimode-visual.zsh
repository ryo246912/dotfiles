zinit light-mode for \
    @'b4b4r07/zsh-vimode-visual'

# 選択範囲を{}で囲うように置き換え
vi-visual-surround-curlybrackets()
{
    zle vi-visual-kill
    BUFFER="$LBUFFER{$CUTBUFFER}$RBUFFER"
    zle vi-visual-exit
}
zle -N vi-visual-surround-curlybrackets

# Escでvi-visual-modeに入る
bindkey '^[' vi-visual-exit
# vでカーソル位置リセット(vi-visual-modeに入り直す)
bindkey -M vivis 'v' vi-visual-mode
# iでviinsモードに入る
bindkey -M vivis "i" vi-insert
# spaceで選択範囲をスペースで囲うように置き換える
bindkey -M vivis " " vi-visual-surround-space
# 'で選択範囲シングルクォートで囲うように置き換える
bindkey -M vivis "'" vi-visual-surround-squote
# "で選択範囲ダブルクォートで囲うように置き換える
bindkey -M vivis "\"" vi-visual-surround-dquote
# ()で選択範囲()で囲うように置き換える
bindkey -M vivis "(" vi-visual-surround-parenthesis
bindkey -M vivis ")" vi-visual-surround-parenthesis
# {}で選択範囲{}で囲うように置き換える
bindkey -M vivis "{" vi-visual-surround-curlybrackets
bindkey -M vivis "}" vi-visual-surround-curlybrackets

# option(alt) + ←→で単語毎のカーソル移動
bindkey -M vivis "^[[1;3C" vi-visual-forward-word
bindkey -M vivis "^[[1;3D" vi-visual-backward-word

terminfo_down_sc=$terminfo[cud1]$terminfo[cuu1]$terminfo[sc]$terminfo[cud1]
left_down_prompt_preexec() {
    print -rn -- $terminfo[el]
}
add-zsh-hook preexec left_down_prompt_preexec

function zle-keymap-select zle-line-init zle-line-finish
{
    case $KEYMAP in
        main|viins)
            # PROMPT_2="$fg[white]-- INSERT --$reset_color"
            PROMPT_2=""
            ;;
        vicmd)
            PROMPT_2="$fg[green]-- NORMAL --$reset_color"
            ;;
        vivis|vivli)
            PROMPT_2="$fg[yellow]-- VISUAL --$reset_color"
            ;;
    esac

    # %{$terminfo_down_sc$PROMPT_2$terminfo[rc]% で下にstatus表示
    PROMPT="
%{$terminfo_down_sc$PROMPT_2$terminfo[rc]%}${MAINPROMPT}"
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select
zle -N edit-command-line
