InstallKeybdHook

; 変換 mode
SC079 & y::Send "^{PgUp}"                         ;「変換」+ y → ctrl + PgUp ;
SC079 & u::PgDn                                   ;「変換」+ u → PgDn ;
SC079 & i::PgUp                                   ;「変換」+ i → PgUp ;
SC079 & o::Send "^{PgDn}"                         ;「変換」+ o → ctrl + PgDn ;
SC079 & h::Left                                   ;「変換」+ h → 左キー
SC079 & j::Down                                   ;「変換」+ j → 左キー
SC079 & k::Up                                     ;「変換」+ k → 左キー
SC079 & l::Right                                  ;「変換」+ l → 左キー
SC079 & n::BackSpace                              ;「変換」+ n → BackSpaceキー
SC079 & m::Tab                                    ;「変換」+ m → Tabキー
SC079 & ,::Send "+{Tab}"                          ;「変換」+ , → Shift + Tabキー
SC079 & .::Enter                                  ;「変換」+ . → Enterキー
SC079 & b::Escape                                 ;「変換」+ b → Escapeキー
SC079 & SC027::AltTab                             ;「変換」+ ; → Alt + Tabキー
SC079 & p::ShiftAltTab                            ;「変換」+ p → Alt + Shift + Tabキー
SC079 & SC15D::SC029                              ;「変換」+ 「カタカナひらがなローマ字」 → 「半角/全角キー」
SC079 & Left::Send "#{Left}"                      ;「変換」+ h → Win + Left ;
SC079 & Down::Send "#{Down}"                      ;「変換」+ j → Win + Down ;
SC079 & Up::Send "#{Up}"                          ;「変換」+ k → Win + Up ;
SC079 & Right::Send "#{Right}"                    ;「変換」+ l → Win + Right ;

;「Right_Control」 → アプリケーションキー ; なんかレジストリも変えないと一部で動作しない?
; SC070::AppsKey
;RControl & h::Send "#{Left}"                     ;「Right_Control」+ h → Win + Left ;
;RControl & j::Send "#{Down}"                     ;「Right_Control」+ j → Win + Down ;
;RControl & k::Send "#{Up}"                       ;「Right_Control」+ k → Win + Up ;
;RControl & l::Send "#{Right}"                    ;「Right_Control」+ l → Win + Right ;

; Mirror-QWERTY mode
Space::Space                                      ;「Space」単体 → Space
Space & 6::5                                      ;「Space」+ 6 → 5
Space & 7::4                                      ;「Space」+ 7 → 4
Space & 8::3                                      ;「Space」+ 8 → 3
Space & 9::2                                      ;「Space」+ 9 → 2
Space & 0::1                                      ;「Space」+ 0 → 1
Space & p::q                                      ;「Space」+ p → q
Space & o::w                                      ;「Space」+ o → w
Space & i::e                                      ;「Space」+ i → e
Space & u::r                                      ;「Space」+ u → r
Space & y::t                                      ;「Space」+ y → t
Space & sc027::a                                  ;「Space」+ ; → a
Space & l::s                                      ;「Space」+ l → s
Space & k::d                                      ;「Space」+ k → d
Space & j::f                                      ;「Space」+ j → f
Space & h::g                                      ;「Space」+ h → g
Space & /::z                                      ;「Space」+ / → z
Space & .::x                                      ;「Space」+ . → x
Space & ,::c                                      ;「Space」+ , → c
Space & m::v                                      ;「Space」+ m → v
Space & n::b                                      ;「Space」+ n → b

;仮想F13(capsLk) mode

; lastkey 	最後に押されたキー
; sendkey 	単押しだった場合に送信するキー
SinglePress(lastkey, sendkey) {
    KeyWait lastkey
    If (A_PriorKey = lastkey)
    {
        Send sendkey
    }
    return
}
F13:: SinglePress("F13", "{SC03A}")               ; 仮想F13(capsLk) → 「capsLk」
F13 & a::Send "!+a"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + a
F13 & b::Send "!+b"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + b
F13 & c::Send "!+c"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + c
F13 & d::Send "!+d"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + d
F13 & e::Send "!+e"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + e
F13 & f::Send "!+f"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + f
F13 & g::Send "!+g"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + g
F13 & h::Send "!+h"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + h
F13 & i::Send "!+i"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + i
F13 & j::Send "!+j"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + j
F13 & k::Send "!+k"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + k
F13 & l::Send "!+l"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + l
F13 & m::Send "!+m"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + m
F13 & n::Send "!+n"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + n
F13 & o::Send "!+o"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + o
F13 & p::Send "!+p"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + p
F13 & q::Send "!+q"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + q
F13 & r::Send "!+r"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + r
F13 & s::Send "!+s"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + s
F13 & t::Send "!+t"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + t
F13 & u::Send "!+u"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + u
F13 & v::Send "!+v"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + v
F13 & w::Send "!+w"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + w
F13 & x::Send "!+x"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + x
F13 & y::Send "!+y"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + y
F13 & z::Send "!+z"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + z
F13 & [::Send "!+["                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + [
F13 & ]::Send "!+]"                               ; 仮想F13(capsLk) +「alt(!)」+ 「shift(+)」 + ]

;shift + 仮想F13(capsLk)
#HotIf GetKeyState("LShift", "P")
F13 & [::Send "!^+["                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ [
F13 & ]::Send "!^+]"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ ]
#HotIf

;ctrl + 仮想F13(capsLk)
#HotIf GetKeyState("LControl", "P")
F13 & a::Send "!^+a"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ a
F13 & b::Send "!^+b"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ b
F13 & c::Send "!^+c"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ c
F13 & d::Send "!^+d"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ d
F13 & e::Send "!^+e"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ e
F13 & f::Send "!^+f"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ f
F13 & g::Send "!^+g"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ g
F13 & h::Send "!^+h"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ h
F13 & i::Send "!^+i"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ i
F13 & j::Send "!^+j"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ j
F13 & k::Send "!^+k"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ k
F13 & l::Send "!^+l"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ l
F13 & m::Send "!^+m"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ m
F13 & n::Send "!^+n"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ n
F13 & o::Send "!^+o"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ o
F13 & p::Send "!^+p"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ p
F13 & q::Send "!^+q"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ q
F13 & r::Send "!^+r"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ r
F13 & s::Send "!^+s"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ s
F13 & t::Send "!^+t"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ t
F13 & u::Send "!^+u"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ u
F13 & v::Send "!^+v"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ v
F13 & w::Send "!^+w"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ w
F13 & x::Send "!^+x"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ x
F13 & y::Send "!^+y"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ y
F13 & z::Send "!^+z"                              ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ z
F13 & Up::Send "!^+{Up}"                          ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ ↑
F13 & Down::Send "!^+{Down}"                      ; 仮想F13(capsLk) +「alt(!)」+ 「ctrl(^)」+「shift(+)」+ ↓
#HotIf

; OneNoteでの設定
#HotIf WinActive("OneNote")
;赤文字にする
F13 & a::Send "{Alt}hfc{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Right}{Enter}"
;青文字にする
F13 & q::Send "{Alt}hfc{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Right}{Right}{Right}{Right}{Right}{Right}{Right}{Enter}"
;黒文字にする
F13 & z::Send "{Alt}hfca"
#HotIf

;「無変換」 mode
SC07B::SC07B
SC07B & a::                                       ;「無変換」 + a → Run Alacritty
{
    try
        if WinExist("Alacritty")
            WinActivate
        else
            Run "Alacritty"
}
SC07B & f::                                       ;「無変換」 + f → Run firefox
{
    if WinExist("Firefox")
        WinActivate
    else
        Run "Firefox"
}
SC07B & m::                                       ;「無変換」 + m → Run MusicBee
{
    try
        if WinExist("MusicBee")
            WinActivate
        else
            Run "MusicBee"
}
SC07B & n::                                       ;「無変換」 + n → Run Notion
{
    try
        if WinExist("Notion")
            WinActivate
        else
            Run "Notion"
}
SC07B & o::                                       ;「無変換」 + o → Run OneNote
{
    try
        if WinExist("OneNote")
            WinActivate
        else
            Run "OneNote"
}
; LAlt & T::                                      ;「Alt」+ t → Run Thunderbird
; {
;     try
;         if WinExist("Thunderbird")
;             WinActivate
;         else
;             Run "Thunderbird"
; }
SC07B & v::                                       ;「無変換」 + v → Run VSCode
{
    try
        if WinExist("Code")
            WinActivate
        else
            Run "Code"
}

; Modifier mode
ModifierStatus := 0
HideTrayTip() {
    TrayTip
}
;「Space」+ 「Right_Control」
Space & RControl::
{
    global ModifierStatus
    if (ModifierStatus = 0)
    {
        ModifierStatus := 10
        TrayTip "Modifier=Control"
        SetTimer HideTrayTip, -800
    }
    else if (ModifierStatus = 10)
    {
        ModifierStatus := 11
        TrayTip "Modifier=Control+Shift"
        SetTimer HideTrayTip, -800
    }
    else if (ModifierStatus = 11)
    {
        ModifierStatus := 0
        TrayTip "Modifier=None"
        SetTimer HideTrayTip, -800
    }
    else
    {
        ModifierStatus := 0
    }
}
;「Space」+ 「Left_Alt」
Space & LAlt::
{
    global ModifierStatus
    if (ModifierStatus = 0)
    {
        ModifierStatus := 20
        TrayTip "Modifier=Alt"
        SetTimer HideTrayTip, -800
    }
    else if (ModifierStatus = 20)
    {
        ModifierStatus := 21
        TrayTip "Modifier=Alt+Shift"
        SetTimer HideTrayTip, -800
    }
    else if (ModifierStatus = 21)
    {
        ModifierStatus := 0
        TrayTip "Modifier=None"
        SetTimer HideTrayTip, -800
    }
    else
    {
        ModifierStatus := 0
    }
}
;「Space」+ 「無変換」
Space & SC07B::
{
    global ModifierStatus
    ModifierStatus := 0
    TrayTip "Modifier=None"
    SetTimer HideTrayTip, -800
}


RemapKey(key) {
    global ModifierStatus
    Send key
    ModifierStatus := 0
}

; Modifier=Control(^)
#HotIf ModifierStatus = 10
    a::RemapKey("^a")
    b::RemapKey("^b")
    c::RemapKey("^c")
    d::RemapKey("^d")
    e::RemapKey("^e")
    f::RemapKey("^f")
    g::RemapKey("^g")
    h::RemapKey("^h")
    i::RemapKey("^i")
    j::RemapKey("^j")
    k::RemapKey("^k")
    l::RemapKey("^l")
    m::RemapKey("^m")
    n::RemapKey("^n")
    o::RemapKey("^o")
    p::RemapKey("^p")
    q::RemapKey("^q")
    r::RemapKey("^r")
    s::RemapKey("^s")
    t::RemapKey("^t")
    u::RemapKey("^u")
    v::RemapKey("^v")
    w::RemapKey("^w")
    x::RemapKey("^x")
    y::RemapKey("^y")
    z::RemapKey("^z")
    1::RemapKey("^1")
    2::RemapKey("^2")
    3::RemapKey("^3")
    4::RemapKey("^4")
    5::RemapKey("^5")
    6::RemapKey("^6")
    7::RemapKey("^7")
    8::RemapKey("^8")
    9::RemapKey("^9")
    F1::RemapKey("^F1")
    F2::RemapKey("^F2")
    F3::RemapKey("^F3")
    F4::RemapKey("^F4")
    F5::RemapKey("^F5")
    F6::RemapKey("^F6")
    F7::RemapKey("^F7")
    F8::RemapKey("^F8")
    F9::RemapKey("^F9")
    F10::RemapKey("^F10")
    F11::RemapKey("^F11")
    F12::RemapKey("^F12")
    Up::Send "{Up}"                               ; ↑
    Down::Send "{Down}"                           ; ↓
    Left::Send "^{Left}"                          ; ctrl + ←
    Right::Send "^{Right}"                        ; ctrl + →
    sc027::RemapKey("^;")                         ; ; → ctrl + ;
    sc028::RemapKey("^:")                         ; : → ctrl + :

    ; 変換 mode
    SC079 & h::Send "^{Left}"                     ; ctrl + ←
    SC079 & j::Send "{Down}"                      ; ↓
    SC079 & k::Send "{Up}"                        ; ↑
    SC079 & l::Send "^{Right}"                    ; ctrl + →

    ; Mirror-QWERTY mode
    Space & 6::RemapKey("^5")                     ;「Space」+ 6 → 5
    Space & 7::RemapKey("^4")                     ;「Space」+ 7 → 4
    Space & 8::RemapKey("^3")                     ;「Space」+ 8 → 3
    Space & 9::RemapKey("^2")                     ;「Space」+ 9 → 2
    Space & 0::RemapKey("^1")                     ;「Space」+ 0 → 1
    Space & p::RemapKey("^q")                     ;「Space」+ p → q
    Space & o::RemapKey("^w")                     ;「Space」+ o → w
    Space & i::RemapKey("^e")                     ;「Space」+ i → e
    Space & u::RemapKey("^r")                     ;「Space」+ u → r
    Space & y::RemapKey("^t")                     ;「Space」+ y → t
    Space & sc027::RemapKey("^a")                 ;「Space」+ ; → a
    Space & l::RemapKey("^s")                     ;「Space」+ l → s
    Space & k::RemapKey("^d")                     ;「Space」+ k → d
    Space & j::RemapKey("^f")                     ;「Space」+ j → f
    Space & h::RemapKey("^g")                     ;「Space」+ h → g
    Space & /::RemapKey("^z")                     ;「Space」+ / → z
    Space & .::RemapKey("^x")                     ;「Space」+ . → x
    Space & ,::RemapKey("^c")                     ;「Space」+ , → c
    Space & m::RemapKey("^v")                     ;「Space」+ m → v
    Space & n::RemapKey("^b")                     ;「Space」+ n → b
#HotIf

; Modifier=Control(^)+Shift(+)
#HotIf ModifierStatus = 11
    a::RemapKey("^+a")
    b::RemapKey("^+b")
    c::RemapKey("^+c")
    d::RemapKey("^+d")
    e::RemapKey("^+e")
    f::RemapKey("^+f")
    g::RemapKey("^+g")
    h::RemapKey("^+h")
    i::RemapKey("^+i")
    j::RemapKey("^+j")
    k::RemapKey("^+k")
    l::RemapKey("^+l")
    m::RemapKey("^+m")
    n::RemapKey("^+n")
    o::RemapKey("^+o")
    p::RemapKey("^+p")
    q::RemapKey("^+q")
    r::RemapKey("^+r")
    s::RemapKey("^+s")
    t::RemapKey("^+t")
    u::RemapKey("^+u")
    v::RemapKey("^+v")
    w::RemapKey("^+w")
    x::RemapKey("^+x")
    y::RemapKey("^+y")
    z::RemapKey("^+z")
    1::RemapKey("^+1")
    2::RemapKey("^+2")
    3::RemapKey("^+3")
    4::RemapKey("^+4")
    5::RemapKey("^+5")
    6::RemapKey("^+6")
    7::RemapKey("^+7")
    8::RemapKey("^+8")
    9::RemapKey("^+9")
    F1::RemapKey("^+F1")
    F2::RemapKey("^+F2")
    F3::RemapKey("^+F3")
    F4::RemapKey("^+F4")
    F5::RemapKey("^+F5")
    F6::RemapKey("^+F6")
    F7::RemapKey("^+F7")
    F8::RemapKey("^+F8")
    F9::RemapKey("^+F9")
    F10::RemapKey("^+F10")
    F11::RemapKey("^+F11")
    F12::RemapKey("^+F12")
    Up::Send "^+{Up}"
    Down::Send "^+{Down}"
    Left::Send "^+{Left}"
    Right::Send "^+{Right}"
    sc027::RemapKey("^+;")                        ; ; → ctrl + shift + ;
    sc028::RemapKey("^+:")                        ; : → ctrl + shift + :

    ; 変換 mode
    SC079 & h::Send "^+{Left}"                    ; ctrl + shift + ←
    SC079 & j::Send "^+{Down}"                    ; ctrl + shift + ↓
    SC079 & k::Send "^+{Up}"                      ; ctrl + shift + ↑
    SC079 & l::Send "^+{Right}"                   ; ctrl + shift + →

    ; Mirror-QWERTY mode
    Space & 6::RemapKey("^+5")                    ;「Space」+ 6 → 5
    Space & 7::RemapKey("^+4")                    ;「Space」+ 7 → 4
    Space & 8::RemapKey("^+3")                    ;「Space」+ 8 → 3
    Space & 9::RemapKey("^+2")                    ;「Space」+ 9 → 2
    Space & 0::RemapKey("^+1")                    ;「Space」+ 0 → 1
    Space & p::RemapKey("^+q")                    ;「Space」+ p → q
    Space & o::RemapKey("^+w")                    ;「Space」+ o → w
    Space & i::RemapKey("^+e")                    ;「Space」+ i → e
    Space & u::RemapKey("^+r")                    ;「Space」+ u → r
    Space & y::RemapKey("^+t")                    ;「Space」+ y → t
    Space & sc027::RemapKey("^+a")                ;「Space」+ ; → a
    Space & l::RemapKey("^+s")                    ;「Space」+ l → s
    Space & k::RemapKey("^+d")                    ;「Space」+ k → d
    Space & j::RemapKey("^+f")                    ;「Space」+ j → f
    Space & h::RemapKey("^+g")                    ;「Space」+ h → g
    Space & /::RemapKey("^+z")                    ;「Space」+ / → z
    Space & .::RemapKey("^+x")                    ;「Space」+ . → x
    Space & ,::RemapKey("^+c")                    ;「Space」+ , → c
    Space & m::RemapKey("^+v")                    ;「Space」+ m → v
    Space & n::RemapKey("^+b")                    ;「Space」+ n → b
#HotIf

; Modifier=Alt(<!)
#HotIf ModifierStatus = 20
    a::RemapKey("<!a")
    b::RemapKey("<!b")
    c::RemapKey("<!c")
    d::RemapKey("<!d")
    e::RemapKey("<!e")
    f::RemapKey("<!f")
    g::RemapKey("<!g")
    h::RemapKey("<!h")
    i::RemapKey("<!i")
    j::RemapKey("<!j")
    k::RemapKey("<!k")
    l::RemapKey("<!l")
    m::RemapKey("<!m")
    n::RemapKey("<!n")
    o::RemapKey("<!o")
    p::RemapKey("<!p")
    q::RemapKey("<!q")
    r::RemapKey("<!r")
    s::RemapKey("<!s")
    t::RemapKey("<!t")
    u::RemapKey("<!u")
    v::RemapKey("<!v")
    w::RemapKey("<!w")
    x::RemapKey("<!x")
    y::RemapKey("<!y")
    z::RemapKey("<!z")
    1::RemapKey("<!1")
    2::RemapKey("<!2")
    3::RemapKey("<!3")
    4::RemapKey("<!4")
    5::RemapKey("<!5")
    6::RemapKey("<!6")
    7::RemapKey("<!7")
    8::RemapKey("<!8")
    9::RemapKey("<!9")
    F1::RemapKey("<!F1")
    F2::RemapKey("<!F2")
    F3::RemapKey("<!F3")
    F4::RemapKey("<!F4")
    F5::RemapKey("<!F5")
    F6::RemapKey("<!F6")
    F7::RemapKey("<!F7")
    F8::RemapKey("<!F8")
    F9::RemapKey("<!F9")
    F10::RemapKey("<!F10")
    F11::RemapKey("<!F11")
    F12::RemapKey("<!F12")
    Up::RemapKey("<!{Up}")
    Down::RemapKey("<!{Down}")
    Left::RemapKey("<!{Left}")
    Right::RemapKey("<!{Right}")
    sc027::RemapKey("^!;")                        ; ; → alt + ;
    sc028::RemapKey("<!:")                        ; : → alt + :

    ; 変換 mode
    SC079 & h::RemapKey("<!{Left}")
    SC079 & j::RemapKey("<!{Down}")
    SC079 & k::RemapKey("<!{Up}")
    SC079 & l::RemapKey("<!{Right}")

    ; Mirror-QWERTY mode
    Space & 6::RemapKey("<!5")                    ;「Space」+ 6 → 5
    Space & 7::RemapKey("<!4")                    ;「Space」+ 7 → 4
    Space & 8::RemapKey("<!3")                    ;「Space」+ 8 → 3
    Space & 9::RemapKey("<!2")                    ;「Space」+ 9 → 2
    Space & 0::RemapKey("<!1")                    ;「Space」+ 0 → 1
    Space & p::RemapKey("<!q")                    ;「Space」+ p → q
    Space & o::RemapKey("<!w")                    ;「Space」+ o → w
    Space & i::RemapKey("<!e")                    ;「Space」+ i → e
    Space & u::RemapKey("<!r")                    ;「Space」+ u → r
    Space & y::RemapKey("<!t")                    ;「Space」+ y → t
    Space & sc027::RemapKey("<!a")                ;「Space」+ ; → a
    Space & l::RemapKey("<!s")                    ;「Space」+ l → s
    Space & k::RemapKey("<!d")                    ;「Space」+ k → d
    Space & j::RemapKey("<!f")                    ;「Space」+ j → f
    Space & h::RemapKey("<!g")                    ;「Space」+ h → g
    Space & /::RemapKey("<!z")                    ;「Space」+ / → z
    Space & .::RemapKey("<!x")                    ;「Space」+ . → x
    Space & ,::RemapKey("<!c")                    ;「Space」+ , → c
    Space & m::RemapKey("<!v")                    ;「Space」+ m → v
    Space & n::RemapKey("<!b")                    ;「Space」+ n → b
#HotIf

; Modifier=Alt(!)+Shift(+)
#HotIf ModifierStatus = 21
    a::RemapKey("!+a")
    b::RemapKey("!+b")
    c::RemapKey("!+c")
    d::RemapKey("!+d")
    e::RemapKey("!+e")
    f::RemapKey("!+f")
    g::RemapKey("!+g")
    h::RemapKey("!+h")
    i::RemapKey("!+i")
    j::RemapKey("!+j")
    k::RemapKey("!+k")
    l::RemapKey("!+l")
    m::RemapKey("!+m")
    n::RemapKey("!+n")
    o::RemapKey("!+o")
    p::RemapKey("!+p")
    q::RemapKey("!+q")
    r::RemapKey("!+r")
    s::RemapKey("!+s")
    t::RemapKey("!+t")
    u::RemapKey("!+u")
    v::RemapKey("!+v")
    w::RemapKey("!+w")
    x::RemapKey("!+x")
    y::RemapKey("!+y")
    z::RemapKey("!+z")
    1::RemapKey("!+1")
    2::RemapKey("!+2")
    3::RemapKey("!+3")
    4::RemapKey("!+4")
    5::RemapKey("!+5")
    6::RemapKey("!+6")
    7::RemapKey("!+7")
    8::RemapKey("!+8")
    9::RemapKey("!+9")
    F1::RemapKey("!+F1")
    F2::RemapKey("!+F2")
    F3::RemapKey("!+F3")
    F4::RemapKey("!+F4")
    F5::RemapKey("!+F5")
    F6::RemapKey("!+F6")
    F7::RemapKey("!+F7")
    F8::RemapKey("!+F8")
    F9::RemapKey("!+F9")
    F10::RemapKey("!+F10")
    F11::RemapKey("!+F11")
    F12::RemapKey("!+F12")
    Up::RemapKey("!+{Up}")
    Down::RemapKey("!+{Down}")
    Left::RemapKey("!+{Left}")
    Right::RemapKey("!+{Right}")
    sc027::RemapKey("^!;")                        ; ; → alt + ;
    sc028::RemapKey("!+:")                        ; : → alt + :

    ; 変換 mode
    SC079 & h::RemapKey("!+{Left}")
    SC079 & j::RemapKey("!+{Down}")
    SC079 & k::RemapKey("!+{Up}")
    SC079 & l::RemapKey("!+{Right}")

    ; Mirror-QWERTY mode
    Space & 6::RemapKey("!+5")                    ;「Space」+ 6 → 5
    Space & 7::RemapKey("!+4")                    ;「Space」+ 7 → 4
    Space & 8::RemapKey("!+3")                    ;「Space」+ 8 → 3
    Space & 9::RemapKey("!+2")                    ;「Space」+ 9 → 2
    Space & 0::RemapKey("!+1")                    ;「Space」+ 0 → 1
    Space & p::RemapKey("!+q")                    ;「Space」+ p → q
    Space & o::RemapKey("!+w")                    ;「Space」+ o → w
    Space & i::RemapKey("!+e")                    ;「Space」+ i → e
    Space & u::RemapKey("!+r")                    ;「Space」+ u → r
    Space & y::RemapKey("!+t")                    ;「Space」+ y → t
    Space & sc027::RemapKey("!+a")                ;「Space」+ ; → a
    Space & l::RemapKey("!+s")                    ;「Space」+ l → s
    Space & k::RemapKey("!+d")                    ;「Space」+ k → d
    Space & j::RemapKey("!+f")                    ;「Space」+ j → f
    Space & h::RemapKey("!+g")                    ;「Space」+ h → g
    Space & /::RemapKey("!+z")                    ;「Space」+ / → z
    Space & .::RemapKey("!+x")                    ;「Space」+ . → x
    Space & ,::RemapKey("!+c")                    ;「Space」+ , → c
    Space & m::RemapKey("!+v")                    ;「Space」+ m → v
    Space & n::RemapKey("!+b")                    ;「Space」+ n → b
#HotIf
