# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "chart.js" # @4.5.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "@fullcalendar/core", to: "@fullcalendar--core.js" # @6.1.21
pin "@fullcalendar/daygrid", to: "@fullcalendar--daygrid.js" # @6.1.21
pin "@fullcalendar/interaction", to: "@fullcalendar--interaction.js" # @6.1.21
pin "@fullcalendar/timegrid", to: "@fullcalendar--timegrid.js" # @6.1.21

# FullCalendar のサブモジュール間の内部参照(bare specifier)解決用。
# 上記4パッケージの内部で "@fullcalendar/core/internal.js" 等を直接 import しているため、
# vendor 済みファイルをフラットな別名として個別に pin する必要がある。
pin "@fullcalendar/core/index.js", to: "@fullcalendar--core.js" # @6.1.21
pin "@fullcalendar/core/internal.js", to: "@fullcalendar--core--internal.js" # @6.1.21
pin "@fullcalendar/core/preact.js", to: "@fullcalendar--core--preact.js" # @6.1.21
pin "@fullcalendar/core/_/DSJtP67n.js", to: "@fullcalendar--core--chunk-DSJtP67n.js" # @6.1.21
pin "@fullcalendar/daygrid/internal.js", to: "@fullcalendar--daygrid--internal.js" # @6.1.21
pin "@fullcalendar/timegrid/internal.js", to: "@fullcalendar--timegrid--internal.js" # @6.1.21

# FullCalendar (core) が内部で使用する preact
pin "preact", to: "preact.js" # @10.12.1
pin "preact/compat", to: "preact--compat.js" # @10.12.1
pin "preact/hooks", to: "preact--hooks.js" # @10.12.1
