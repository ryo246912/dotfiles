-- ~/.config/hammerspoon 配下のファイル変更（chezmoi apply 等）で設定を自動リロードする
configWatcher = hs.pathwatcher
  .new(hs.configdir, function(files)
    for _, file in ipairs(files) do
      if file:sub(-4) == '.lua' then
        hs.reload()
        return
      end
    end
  end)
  :start()

-- アプリごとの JankyBorders の枠の色（ルールは app_borders_rules.lua）
appBorders = require('app_borders')
appBorders.start(require('app_borders_rules'))

hs.alert.show('Hammerspoon config loaded')
