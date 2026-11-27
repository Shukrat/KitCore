local addonName, ns = ...

---------------------------------------------------------------------------
-- Kit Core: the parts every kit shares, for WoW Forever.
--
-- A kit is a round button that opens into a ring of slots. Kit Core builds
-- and runs all of that from a description the kit hands it: the button,
-- its slots (with the small corner buttons some of them carry), opening and
-- closing, pinning a slot so it stays out with the kit closed, flyouts of
-- choices, dragging, keeping it on screen, laying it out on a screen edge,
-- the settings panel, the minimap button, slash commands and key bindings.
-- The kit itself only says what each slot does.
--
-- Kit Dock is optional. With it, a kit can join the gold pin with the other
-- kits and snap to the screen edges (or only the edges); without it, the kit
-- stands on its own.
--
-- Every kit ships its own copy of this file in Libs/KitCore. The newest copy
-- loaded runs for every kit (see VERSION), the same way Kit Dock works.
--
-- Flyouts are secure: their choices cast spells, use items or change what a
-- slot holds, and they open and close in combat too. Where the choices sit
-- is worked out out of combat, whenever the kit refreshes.
--
-- So does the kit button (from v5), for a kit that floats or sits on a screen
-- edge. The game won't let an addon move or show a secure slot in combat, so
-- every refresh works out both layouts, open and closed, and hands each slot
-- where it goes and whether it shows in each. A click on the button in combat
-- runs a secure snippet that switches the slots between the two. Kits on the
-- pin with other kits still open and close out of combat only.
--
-- From v6 the kit can be dragged in combat too (same kits): a faint copy of
-- the button (not secure) follows the mouse, and where you let go, a secure
-- snippet puts the real button (see GRIP_CLICK). When combat ends the drop
-- is finished like any other drag: saved, and snapped to an edge or another
-- kit if it's near one.
--
-- From v18 the kits work with the game's Quick Keybind Mode (Esc > Options >
-- Keybindings > Quick Keybind Mode, or /keybind): while it's up every kit
-- opens fully, and hovering any slot, corner button or kit button and
-- pressing a key binds it there, as on the action bars.
--
-- From v19 the minimap button goes through LibDataBroker and LibDBIcon, which
-- ship in Libs/KitCore/Libs: a kit's .toc loads Libs\KitCore\Libs\Libs.xml
-- first. Square minimaps and button-bag addons then handle it properly.
--
-- From v21 there's a reminder panel, one for every kit, that can be moved
-- anywhere. Each kit chooses whether it uses it; for a kit that does, the
-- reminders you tick in its settings show there (as full-size copies that
-- glow, count down and cast like the slot) instead of beside the closed kit,
-- and stay there while it's open. A pinned slot stays by its kit, reminder
-- or not: pinning means "keep it here". From v26 a kit can ask for its
-- pinned reminders to show in the panel as well (cfg.panelPinned): the slot
-- stays by the kit and a copy of it goes in the panel too.
--
-- From v23 a kit can let its buttons be dragged off it (cfg.bars). In its
-- edit mode (the kit's right-click menu, its settings, or "layout" after its
-- slash command) every button can be dragged: dropped away from the kit it
-- floats there, always shown, and dropping another on it makes a bar, in any
-- order. Dropped on the kit it goes back to its place. A button on a bar is
-- the slot itself, moved, so its drawer, corner button, glow and key binding
-- all come with it; the kit's own layout closes up round the gap. See "Bars".
--
-- From v31 a zone can hold small buttons (zone small): each slot that can
-- move between zones takes the size of the one it's in, small there and a
-- full slot in the others (or on a bar), changing as it's dragged. A
-- zone can take only some slots (zone only), and a ring of small buttons
-- inside another ring can have its outline run through its buttons
-- (zone track; from v35 every ring shows its whole band instead). See "Zones".
--
-- From v32 a slot with a drawer can open it from its reminder too
-- (slot.panelFlyout): right-click its copy in the reminder panel, or a
-- kit's own reminder button for it (Kit:OpenFlyoutAt), and the drawer
-- opens beside that, toward the middle of the screen. Out of combat.
-- Also from v32: a slot the kit has hidden (btn.hidden) but marked
-- btn.panelWhenHidden still sends its reminder to the reminder panel.
--
-- From v33 the words Kit Core shows go through KitCore.L, in the player's
-- language (Simplified Chinese so far; anything untranslated stays English).
--
-- From v35 edit mode shows where a dragged button will go: each ring zone
-- owns a band round the kit (Kit:ZoneBands; rings one inside another meet
-- halfway between them, so they never overlap), shaded, and a drop anywhere
-- in it, at any angle, goes on that ring. The band it would land in lights
-- up; the button under the mouse takes the size it would be there and says
-- where it'll go (the zone's name, a bar, on its own, back in its place),
-- and a gold ring marks the spot it would take.
--
-- From v38 the bars go on the placing grid (the one Move everything uses):
-- edit mode shows the grid under the kits, with its Grid size and Snap on
-- edit mode's bar, and a bar dragged by its box, or a button floating on its
-- own, snaps to the screen's middle lines, the kit buttons and the other
-- bars, or else its left and top edges to the grid. Shift places it freely.
-- The bars are things the placed pieces line up with too. Placing and edit
-- mode go together: Move everything also puts the kit it's pressed from
-- into edit mode, edit mode's bar is the one bar while both run, and its
-- Done (or Esc) ends both.
--
-- From v39 a kit (cfg.radial) can be used from a controller as a ring round
-- the middle of the screen: hold its binding (or press a /click macro on a
-- gamepad bar), tilt a stick at a button, let go. The kit's ring, its inner
-- ring and its row under the line are three rings; drawers open as rings of
-- their own. All of it works in combat. See "The radial".
---------------------------------------------------------------------------

local VERSION = 39
-- Builds of the same VERSION (test builds while a version is in a pull
-- request): the higher one wins too, so two kits carrying different builds
-- of one version don't leave the older running for every kit. Raise it with
-- each change while VERSION stays put; back to 0 with a new VERSION.
local BUILD = 0
local C = _G.KitCore
if C and ((C.version or 0) > VERSION or ((C.version or 0) == VERSION and (C.build or 0) >= BUILD)) then
    ns.Core = C
    return
end
C = C or {}
_G.KitCore = C
ns.Core = C
C.version = VERSION
C.build = BUILD

-- The words on screen (KitCore.L), keyed by their English: Loc["Settings"]. A
-- key with no translation comes back as itself, so English needs no entries
-- and a string nobody has translated shows in English. The table is this
-- copy's own, rebuilt whenever a newer copy takes over, so the text always
-- matches the code that's running. It's Loc here, not L: this file already
-- uses L for left edges and lengths. Kits keep their own text in their own
-- tables (ns.L); this one is only for what Kit Core itself shows.
local Loc = setmetatable({}, { __index = function(_, key) return key end })
C.L = Loc
do
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhCN" then
        -- Simplified Chinese: Loc["English, exactly as in the code"] = "中文"
        Loc["Open / close the kit"] = "打开/关闭套件"
        Loc["Use %s"] = "使用%s"
        Loc["Left-click: open / close"] = "左键点击：打开/关闭"
        Loc["Drag: move"] = "拖动：移动"
        Loc["Right-click: menu   Shift-right-click: settings"] = "右键点击：菜单   Shift+右键点击：设置"
        Loc["That can only change out of combat."] = "只能在脱离战斗后更改。"
        Loc["Pinned in place."] = "已固定位置。"
        Loc["Unpinned. Drag the kit to move it."] = "已取消固定。拖动套件即可移动。"
        Loc["Place"] = "放置"
        Loc["On the pin"] = "停靠点上"
        Loc["Tuck box"] = "收纳框"
        Loc["Free"] = "自由"
        Loc["Pin in place"] = "固定位置"
        Loc["Done editing layout"] = "完成布局编辑"
        Loc["Edit layout"] = "编辑布局"
        Loc["Settings"] = "设置"
        Loc["Click: open"] = "点击：打开"
        Loc["Right-click: choose"] = "右键点击：选择"
        Loc["On a bar: always shown"] = "在按钮条上：始终显示"
        Loc["Shift-right-click: stop always showing"] = "Shift+右键点击：取消始终显示"
        Loc["Shift-right-click: always show"] = "Shift+右键点击：始终显示"
        Loc["Nothing to choose from."] = "没有可选项。"
        Loc["Drag: move it in this list"] = "拖动：在此列表中移动"
        Loc["the press didn't reach the kit's secure code"] = "按键没有传到套件的安全代码"
        Loc["the game didn't give the kit the mouse position"] = "游戏没有把鼠标位置交给套件"
        Loc["the game didn't give the kit the mouse position on release"] = "松开时游戏没有把鼠标位置交给套件"
        Loc["the game didn't give the kit the button's position"] = "游戏没有把按钮位置交给套件"
        Loc["the game didn't let the kit move the button"] = "游戏没有允许套件移动按钮"
        Loc["Couldn't move the kit in combat: %s."] = "无法在战斗中移动套件：%s。"
        Loc["stopped at %s"] = "停在了 %s"
        Loc["Click the kit button to open or close it in combat."] = "战斗中请点击套件按钮来打开或关闭它。"
        Loc["%s is on a bar, so it's always shown. Edit the layout to move it."] = "%s在按钮条上，所以始终显示。编辑布局可移动它。"
        Loc["%s: always shown."] = "%s：始终显示。"
        Loc["%s: hides when the kit closes."] = "%s：套件关闭时隐藏。"
        Loc["Left-click: settings"] = "左键点击：设置"
        Loc["Right-click: open / close the kit"] = "右键点击：打开/关闭套件"
        Loc["Drag: move around the minimap"] = "拖动：沿小地图移动"
        Loc["The settings panel isn't available on this build. %s help lists the slash commands."] = "此版本没有设置面板。%s help 可列出斜杠命令。"
        Loc["Kit"] = "套件"
        Loc["General"] = "常规"
        Loc["Show %s"] = "显示 %s"
        Loc["Turn off to hide the whole kit (its button and every slot) without uninstalling it."] = "关闭即可隐藏整个套件（它的按钮和所有栏位），无需卸载。"
        Loc["Lock it in place"] = "锁定位置"
        Loc["Stop the kit from being dragged. Also in the kit's right-click menu."] = "禁止拖动套件。也可在套件的右键菜单中设置。"
        Loc["Tuck at screen edge"] = "在屏幕边缘收起"
        Loc["On a screen edge on its own, the kit slides half off the screen until you mouse over it. Turn off to keep it fully on the screen. In a tuck box it still tucks with the box."] = "套件单独位于屏幕边缘时，会滑出屏幕一半，直到鼠标移上去。关闭则始终完整留在屏幕上。在收纳框中时它仍随收纳框一起收起。"
        Loc["Minimap button"] = "小地图按钮"
        Loc["Left-click for these settings, right-click to open the kit, drag to move it."] = "左键点击打开这些设置，右键点击打开套件，拖动可移动它。"
        Loc["Chat messages"] = "聊天消息"
        Loc["Notices in chat when something changes (pinned in place, always shown, snoozed and the like). Slash commands still answer in chat."] = "有变化时在聊天中提示（固定位置、始终显示、暂停提醒等）。斜杠命令仍会在聊天中回复。"
        Loc["In combat"] = "战斗中"
        Loc["Hide the kit in combat"] = "战斗中隐藏套件"
        Loc["Hide the kit while you're in combat."] = "战斗中隐藏套件。"
        Loc["Drawers close after"] = "弹出栏关闭延迟"
        Loc["In combat a drawer can't close when you click elsewhere, so it closes by itself this long after the mouse leaves it and its slot."] = "战斗中点击别处无法关闭弹出栏，所以鼠标离开它和它的栏位这么久后会自动关闭。"
        Loc["Fading"] = "淡出"
        Loc["Fade the kit"] = "套件淡出"
        Loc["When closed: the closed kit and its pinned slots fade until you mouse over them. When left open: the open kit fades once the mouse has been off it a while (it stays open). Mouse over to bring it back."] = "关闭时：关闭的套件及其固定栏位会淡出，直到鼠标移上去。保持打开时：鼠标离开一段时间后，打开的套件会淡出（仍保持打开）。鼠标移上去即恢复。"
        Loc["Never"] = "从不"
        Loc["When closed"] = "关闭时"
        Loc["When left open"] = "保持打开时"
        Loc["Both"] = "两者"
        Loc["Fade when idle"] = "闲置时淡出"
        Loc["With the kit closed, it and its pinned slots fade until you mouse over them."] = "套件关闭时，它和它的固定栏位会淡出，直到鼠标移上去。"
        Loc["Fade when left open"] = "保持打开时淡出"
        Loc["With the kit open, it and its slots fade once the mouse has been off them for a while. They stay open, and come back when you mouse over them."] = "套件打开时，鼠标离开一段时间后它和它的栏位会淡出。它们保持打开，鼠标移上去即恢复。"
        Loc["Fade an open kit after"] = "打开的套件淡出延迟"
        Loc["How long the mouse has to be off the open kit before it fades."] = "鼠标离开打开的套件多久后它才淡出。"
        Loc["How faded"] = "淡出程度"
        Loc["How see-through the kit's slots get when it fades: 0% is gone until you mouse over. The kit button fades half as much, so you can still find it."] = "淡出时套件栏位的透明程度：0% 表示完全消失，直到鼠标移上去。套件按钮只淡出一半，方便你找到它。"
        Loc["Look"] = "外观"
        Loc["Size"] = "大小"
        Loc["Whole kit"] = "整个套件"
        Loc["The whole kit: the center icon, the buttons round it and the space between them."] = "整个套件：中心图标、周围的按钮以及它们之间的间距。"
        Loc["Center icon"] = "中心图标"
        Loc["Just the icon in the middle: the buttons round it stay where they are."] = "只有中间的图标：周围的按钮位置不变。"
        Loc["Buttons"] = "按钮"
        Loc["Just the buttons round the center icon: each gets smaller in its place, so they spread out a little."] = "只有中心图标周围的按钮：每个按钮在原位变小，所以会稍微散开。"
        Loc["Spread"] = "间距"
        Loc["How far the buttons sit from the center icon: lower brings them in close, higher spreads them out."] = "按钮离中心图标多远：数值小则靠拢，数值大则散开。"
        Loc["Layout"] = "布局"
        Loc["Buttons open toward"] = "按钮展开方向"
        Loc["Which way the slots lay out round the kit while it's floating. On a screen edge they always face the middle of the screen."] = "套件浮动时栏位围绕它排列的方向。在屏幕边缘时它们始终朝向屏幕中央。"
        Loc["Up"] = "向上"
        Loc["Down"] = "向下"
        Loc["Left"] = "向左"
        Loc["Right"] = "向右"
        Loc["Reminders"] = "提醒"
        Loc["Tooltips"] = "鼠标提示"
        Loc["Where a slot's tooltip shows: beside the slot, or where the game normally puts tooltips."] = "栏位的鼠标提示显示在哪里：栏位旁边，或游戏通常显示鼠标提示的位置。"
        Loc["Beside the slot"] = "栏位旁边"
        Loc["Game's spot"] = "游戏默认位置"
        Loc["Default tooltip position"] = "默认鼠标提示位置"
        Loc["Show slot tooltips where the game normally shows tooltips, instead of beside the slot."] = "在游戏通常显示鼠标提示的位置显示栏位提示，而不是在栏位旁边。"
        Loc["Pinned buttons"] = "固定按钮"
        Loc["Keep it out when the kit is closed (this character only). You can also shift-right-click the slot."] = "套件关闭时保留在外（仅限此角色）。也可以 Shift+右键点击栏位。"
        Loc["Slot choices"] = "栏位选择"
        Loc["Reset"] = "重置"
        Loc["Put every slot back to its starting choice, and every list back in its starting order."] = "把每个栏位恢复为初始选择，每个列表恢复初始顺序。"
        Loc["Bars"] = "按钮条"
        Loc["Edit"] = "编辑"
        Loc["Opens the kit and lets you drag its buttons. The shaded areas show where a button can go on the kit: drop it there, between two buttons or at an end. Drop a button away from the kit and it floats there, always shown. Drop another on it to make a bar, or between two to put it there. Drop a button on the kit's icon to put it back. Drag a bar by its box to move it. This character only; out of combat. Also in the kit's right-click menu."] = "打开套件并允许你拖动它的按钮。阴影区域显示按钮可以放在套件上的哪些位置：放到那里、两个按钮之间或末端。把按钮拖离套件，它就会浮动在那里并始终显示。再拖一个到它上面可组成一个按钮条，或拖到两个之间插入。把按钮拖到套件图标上可放回去。拖动按钮条的框可移动整个按钮条。仅限此角色；需脱离战斗。也可在套件的右键菜单中打开。"
        Loc["Spacing"] = "间距"
        Loc["Room between the buttons on a bar."] = "按钮条上按钮之间的间隔。"
        Loc["Reset to defaults"] = "恢复默认"
        Loc["Put every button back where it started: off the bars, and the kit's own buttons in their usual places and order."] = "把每个按钮放回原处：从按钮条上取下，套件自己的按钮回到原来的位置和顺序。"
        Loc["Reminder panel"] = "提醒面板"
        Loc["Put %s's reminders in the panel"] = "把 %s 的提醒放进面板"
        Loc["One panel for all your kits that you can put anywhere. With this on and %s closed, its reminders show there, full size, instead of beside the kit. They stay in the panel while the kit is open too (and in their places in the kit). Each kit has its own switch, so some kits' reminders can be in the panel and others by their kit."] = "一个供所有套件共用、可随意放置的面板。开启后，%s 关闭时它的提醒会以完整大小显示在面板里，而不是在套件旁边。套件打开时它们也留在面板里（同时也在套件中各自的位置）。每个套件有自己的开关，所以可以让一些套件的提醒在面板里，另一些在各自套件旁。"
        Loc["A pinned button stays by its kit, and its reminder shows in the panel too."] = "固定的按钮留在套件旁，它的提醒也会显示在面板里。"
        Loc["A pinned button always stays by its kit."] = "固定的按钮始终留在套件旁。"
        Loc["The panel (every kit)"] = "面板（所有套件）"
        Loc["Place the panel"] = "放置面板"
        Loc["Move"] = "移动"
        Loc["Shows a grid and the panel's box of buttons: drag it where you want it. It snaps to the grid, the middle of the screen and your kit buttons; hold Shift to place it freely."] = "显示网格和面板的按钮框：把它拖到想要的位置。它会吸附到网格、屏幕中线和你的套件按钮；按住 Shift 可自由放置。"
        Loc["Rows: buttons side by side, then a new row. Columns: one under another, then a new column."] = "行：按钮并排，排满后另起一行。列：按钮上下排列，排满后另起一列。"
        Loc["Rows"] = "行"
        Loc["Columns"] = "列"
        Loc["Buttons per row"] = "每行按钮数"
        Loc["How many across before a new row starts."] = "一行排多少个后另起一行。"
        Loc["Buttons per column"] = "每列按钮数"
        Loc["How many down before a new column starts."] = "一列排多少个后另起一列。"
        Loc["Grow from the middle"] = "从中间展开"
        Loc["The first button sits in the middle of the row (column), the next ones spread out evenly either side, and each new row (column) starts in the middle again. Off: they fill from the corner below."] = "第一个按钮位于行（列）的中间，之后的按钮向两侧均匀展开，每个新的行（列）再从中间开始。关闭：从下面选定的角落开始填充。"
        Loc["Start from"] = "起始角落"
        Loc["The corner the first button goes in (growing from the middle: the side new rows or columns are added toward). The panel grows away from it, and stays put there."] = "第一个按钮所在的角落（从中间展开时：新的行或列添加的方向）。面板从这里向外扩展，这个角落保持不动。"
        Loc["Top left"] = "左上"
        Loc["Top right"] = "右上"
        Loc["Bottom left"] = "左下"
        Loc["Bottom right"] = "右下"
        Loc["Button size"] = "按钮大小"
        Loc["The buttons in the panel, the same for every kit (100% is a full slot)."] = "面板中的按钮大小，所有套件相同（100% 为完整栏位大小）。"
        Loc["Room between the buttons."] = "按钮之间的间隔。"
        Loc["Snap when placing"] = "放置时吸附"
        Loc["Line the panel up with the grid, the middle of the screen and your kit buttons as you drag it."] = "拖动面板时让它对齐网格、屏幕中线和你的套件按钮。"
        Loc["Grid size"] = "网格大小"
        Loc["How far apart the grid's lines are while placing it."] = "放置时网格线之间的距离。"
        Loc["Reminders in the panel"] = "面板中的提醒"
        Loc["When it pops out with the kit closed (missing or wanted), it shows in the panel."] = "套件关闭时它弹出（缺少或需要）会显示在面板里。"
        Loc["Pinned, it shows in the panel too, and stays by the kit."] = "固定时，它也会显示在面板里，同时留在套件旁。"
        Loc["Pinned, it stays by the kit."] = "固定时，它留在套件旁。"
        Loc["Key bindings"] = "按键绑定"
        Loc["Open"] = "打开"
        Loc["Bind each slot, and opening the kit."] = "为每个栏位以及打开套件绑定按键。"
        Loc["Slot choices reset."] = "栏位选择已重置。"
        Loc["Open Esc > Options > Keybindings and look for %s."] = "打开 Esc > 选项 > 按键绑定，找到 %s。"
        Loc["Kit reminders"] = "套件提醒"
        Loc["Drag to move. Hold Shift to place it freely."] = "拖动以移动。按住 Shift 可自由放置。"
        Loc["Right-click when you're done."] = "完成后右键点击。"
        Loc["Drag to move, Shift for free"] = "拖动以移动，按住 Shift 自由放置"
        Loc["Snap"] = "吸附"
        Loc["Done"] = "完成"
        Loc["Grid %s"] = "网格 %s"
        Loc["Placing %s"] = "正在放置%s"
        Loc["Moving everything"] = "全部移动中"
        Loc["Things can only be moved out of combat."] = "只能在脱离战斗后移动。"
        Loc["Nothing to move: turn on the reminder panel or a kit's timers first. The kits themselves move by dragging them."] = "没有可移动的：请先开启提醒面板或某个套件的计时器。套件本身直接拖动即可移动。"
        Loc["the reminder panel"] = "提醒面板"
        Loc["The reminder panel can only move out of combat."] = "提醒面板只能在脱离战斗后移动。"
        Loc["Turn on the reminder panel for a kit first (its Settings > Reminder panel)."] = "请先为某个套件开启提醒面板（它的设置 > 提醒面板）。"
        Loc["Layout reset: every button is back in its usual place."] = "布局已重置：每个按钮都回到了原来的位置。"
        Loc["Drag to move it."] = "拖动以移动。"
        Loc["Drop it on the kit to put it back."] = "拖到套件上可放回去。"
        Loc["Drop it away from the kit to float it."] = "拖离套件可让它浮动。"
        Loc["Bar"] = "按钮条"
        Loc["Drag to move the whole bar."] = "拖动以移动整个按钮条。"
        Loc["On a bar"] = "放到按钮条上"
        Loc["Floating on its own"] = "单独浮动"
        Loc["Back in its place"] = "放回原位"
        Loc["Drag a button into one of the kit's shaded areas to move it there: the one it would land in lights up, and the label under the button says where it'll go. Drop it away from the kit and it floats, always shown; drop another on it to make a bar. Drop it on the kit's icon to put it back. Drag a bar's box to move it."] = "把按钮拖进套件的某个阴影区域即可移到那里：它将落入的区域会亮起，按钮下方的标签会说明它的去向。拖离套件它就会浮动并始终显示；再拖一个到它上面可组成一个按钮条。拖到套件图标上可放回去。拖动按钮条的框可移动它。"
        Loc["Bars and buttons on their own snap to the grid, the middle of the screen, the kit buttons and other bars; hold Shift to place them freely."] = "按钮条和单独浮动的按钮会吸附到网格、屏幕中线、套件按钮和其他按钮条；按住 Shift 可自由放置。"
        Loc["Drag to move the whole bar. It snaps to the grid; hold Shift to place it freely."] = "拖动以移动整个按钮条。它会吸附到网格；按住 Shift 可自由放置。"
        Loc["Editing %s's layout, placing %s"] = "正在编辑 %s 的布局，放置 %s"
        Loc["The reminder panel and the kits' timers and bars move by dragging them, snapping the same way."] = "提醒面板以及各套件的计时器和计时条也可拖动移动，吸附方式相同。"
        Loc["The kit's own buttons and bars too, as in Edit layout."] = "也包括本套件自己的按钮和按钮条，与编辑布局相同。"
        Loc["The layout can only be edited out of combat."] = "布局只能在脱离战斗后编辑。"
        Loc["Show the kit first."] = "请先显示套件。"
        Loc["Close Quick Keybind Mode first."] = "请先关闭快速按键绑定模式。"
        Loc["Editing %s's layout"] = "正在编辑 %s 的布局"
        Loc["Custom..."] = "自定义…"
        Loc["Custom"] = "自定义"
        Loc["Pick any colour in the game's colour picker. Cancel puts back what you had."] = "在游戏的颜色选择器中选择任意颜色。取消则恢复原来的颜色。"
        Loc["No setting matches that. Try another word."] = "没有匹配的设置。换个词试试。"
        Loc["Settings with \"%s\""] = "包含“%s”的设置"
        Loc["%s settings"] = "%s 设置"
        Loc["Find a setting"] = "查找设置"
        Loc["Move everything"] = "全部移动"
        Loc["The reminder panel and every timer and bar in use, shown where they sit on a grid so you can drag them all at once. Done (or Esc) when you're finished."] = "提醒面板以及所有使用中的计时器和条，在网格上显示在各自的位置，可以一次全部拖动。完成后点击“完成”（或按 Esc）。"
        Loc["Also %s move."] = "也可用 %s move。"
        Loc["The kit's settings are in its own window. Also from the minimap button, the kit's right-click menu or %s."] = "套件的设置在它自己的窗口中。也可从小地图按钮、套件的右键菜单或 %s 打开。"
        Loc["its slash command"] = "它的斜杠命令"
        Loc["Settings panel failed to load (%s). %s help lists the slash commands."] = "设置面板加载失败（%s）。%s help 可列出斜杠命令。"
        Loc["%s - settings"] = "%s - 设置"
        Loc["%s minimap - show or hide the minimap button"] = "%s minimap - 显示或隐藏小地图按钮"
        Loc["%s face up | down | left | right - which way the layout points"] = "%s face up | down | left | right - 布局朝向"
        Loc["%s move - move everything: the reminder panel and the kits' timers and bars, all at once"] = "%s move - 全部移动：提醒面板以及各套件的计时器和条，一次完成"
        Loc["%s panel - move the reminder panel (shared by every kit)"] = "%s panel - 移动提醒面板（所有套件共用）"
        Loc["%s layout - drag buttons off the kit onto bars"] = "%s layout - 把按钮从套件拖到按钮条上"
        Loc["%s dock - dock every kit on the pin"] = "%s dock - 把所有套件停靠到停靠点"
        Loc["Locked."] = "已锁定。"
        Loc["Unlocked. Drag the kit to move it."] = "已解锁。拖动套件即可移动。"
        Loc["Kits docked together on the pin."] = "套件已一起停靠到停靠点。"
        Loc["Docking needs another kit installed."] = "停靠需要安装另一个套件。"
        Loc["%s face up | down | left | right   (now %s)"] = "%s face up | down | left | right   （当前 %s）"
        Loc["Kit moved back to its starting spot."] = "套件已回到初始位置。"
        Loc["Minimap button shown."] = "小地图按钮已显示。"
        Loc["Minimap button hidden. %s minimap brings it back."] = "小地图按钮已隐藏。%s minimap 可恢复。"
        Loc["Unknown command. %s help lists them."] = "未知命令。%s help 可列出命令。"
        Loc["Press Escape to unbind."] = "按 Esc 解除绑定。"
        Loc["Not bound"] = "未绑定"
        Loc["Press a key to bind."] = "按下一个键进行绑定。"
        Loc["Radial (controller)"] = "环形菜单（手柄）"
        Loc["Below the line"] = "分隔线下方"
        Loc["Back to the ring"] = "返回主环"
        Loc["Inner ring"] = "内环"
        Loc["Stick centred + X: inner ring"] = "摇杆居中 + X：内环"
        Loc["Tilt the stick"] = "推动摇杆"
        Loc["Cast"] = "施放"
        Loc["Use"] = "使用"
        Loc["Alternate"] = "备选"
        Loc["Close"] = "关闭"
        Loc["Back"] = "返回"
        Loc["Couldn't make the macro: your macro slots may be full."] = "无法创建宏：你的宏栏位可能已满。"
        Loc["Macro \"%s\" is on your cursor: drop it on a gamepad bar slot."] = "宏“%s”已在你的光标上：把它放到手柄动作条的栏位上。"
        Loc["Controller"] = "手柄"
        Loc["Radial on a controller"] = "手柄环形菜单"
        Loc["Use %s from a controller as a ring round the middle of the screen: hold its binding, tilt a stick at a button, let go. Works in combat."] = "用手柄以屏幕中央的环形菜单使用%s：按住它的绑定键，把摇杆推向某个按钮，然后松开。战斗中也可使用。"
        Loc["Opening it"] = "打开方式"
        Loc["Gamepad bar"] = "手柄动作条"
        Loc["Make macro"] = "创建宏"
        Loc["Puts a macro on your cursor that brings the ring up: drop it on a gamepad bar slot. Hold its button, tilt the stick at a button and let go; or tap it and use A."] = "在光标上放一个打开环形菜单的宏：把它放到手柄动作条的栏位上。按住它的按键，把摇杆推向一个按钮再松开；或者轻按一下，再用 A 使用。"
        Loc["Key binding"] = "按键绑定"
        Loc["Bind a button to bring the ring up: hold it, tilt, let go. Under %s in the key bindings."] = "绑定一个打开环形菜单的按钮：按住、推动摇杆、松开。在按键绑定的 %s 下。"
        Loc["Picking"] = "选择"
        Loc["Pick with"] = "选择用摇杆"
        Loc["The stick that points at a button while the ring is up."] = "环形菜单打开时用来指向按钮的摇杆。"
        Loc["Right stick"] = "右摇杆"
        Loc["Left stick"] = "左摇杆"
        Loc["Hold the camera still"] = "选择时固定镜头"
        Loc["While the ring is up, the stick you pick with doesn't turn the camera (or move you, for the left stick)."] = "环形菜单打开时，用来选择的摇杆不会转动镜头（左摇杆则不会移动角色）。"
        Loc["Ring"] = "环形"
        Loc["Ring size"] = "环形大小"
        Loc["Button names"] = "按钮名称"
        Loc["Each button's name under it."] = "在每个按钮下方显示名称。"
        Loc["While it's up: A uses, X opens a drawer or the row under the line (with the stick centred: the inner ring), Y does a button's alternate, B goes back or closes."] = "打开时：A 使用，X 打开弹出栏或分隔线下方一行（摇杆居中时：内环），Y 执行按钮的备选操作，B 返回或关闭。"
    end
end

-- Kits are tables with this as their metatable. A newer copy loaded later
-- replaces the methods in place, so kits made by an older copy pick them up.
C.proto = C.proto or {}
local Kit = C.proto
Kit.__index = Kit

---------------------------------------------------------------------------
-- Helpers (also for the kits: KitCore.U)
---------------------------------------------------------------------------

local U = {}
C.U = U

function U.Sealed(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function U.ItemCount(id)
    if not id then return 0 end
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    if GetItemCount then return GetItemCount(id) or 0 end
    return 0
end

-- Uses left, counting charges rather than items, like bag slots do.
function U.ItemUses(id)
    if not id then return 0 end
    local n
    if C_Item and C_Item.GetItemCount then n = C_Item.GetItemCount(id, false, true)
    elseif GetItemCount then n = GetItemCount(id, false, true) end
    return n or U.ItemCount(id)
end

function U.Owned(id) return U.ItemCount(id) > 0 end

function U.ItemIcon(id)
    local icon = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return icon or 134400 -- question mark
end

function U.ItemName(id)
    return id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or nil
end

function U.SpellIcon(id)
    return id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400
end

function U.SpellName(id)
    return id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
end

-- A spell you know, looked up by name (the version in your spellbook), or nil.
function U.SpellByName(name)
    if not (name and C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    return ok and info and info.spellID or nil
end

function U.Known(spellID)
    if not spellID then return false end
    return (IsPlayerSpell and IsPlayerSpell(spellID))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
        or false
end

function U.ItemCooldown(id)
    if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(id) end
    if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(id) end
end

function U.SpellCooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and info then return info.startTime, info.duration, info.isEnabled end
        return
    end
    if GetSpellCooldown then return GetSpellCooldown(id) end
end

function U.SetCooldown(cd, start, duration, enable)
    if start and duration then
        if U.Sealed(start) or U.Sealed(duration) then
            pcall(cd.SetCooldown, cd, start, duration)
        elseif duration > 1.5 and enable ~= 0 and enable ~= false then -- (not the global cooldown)
            cd:SetCooldown(start, duration)
        else
            cd:Clear()
        end
    else
        cd:Clear()
    end
end

function U.FormatLeft(left)
    if left >= 3600 then return math.floor(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
end

function U.InList(list, v)
    for i, x in ipairs(list or {}) do if x == v then return i end end
end

function U.ApplyDefaults(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then
            if type(v) == "table" then
                t[k] = {}
                U.ApplyDefaults(t[k], v)
            else
                t[k] = v
            end
        end
    end
end

-- A value, or what a function gives for it.
local function Val(x, ...)
    if type(x) == "function" then return x(...) end
    return x
end
U.Val = Val

-- Art ships in several sizes: WoW doesn't mipmap addon TGAs, and plain
-- bilinear sampling goes jagged once a texture is shrunk past 2x. Pick the
-- smallest size that's still at least the on-screen pixel size.
local ART_SIZES = { 32, 48, 64, 96, 128, 256 }  -- slot rings
local PROF_RING_SIZES = { 32, 48, 64, 128 }     -- the small round buttons' ring
local function ArtSize(px, sizes)
    for _, s in ipairs(sizes) do if px <= s then return s end end
    return sizes[#sizes]
end
local function ScreenPx(frame, units)
    local h = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) -- (an "and" would keep only the width)
    if h and h > 0 then return units * frame:GetEffectiveScale() * h / 768 end
    return units
end

U.ArtSize, U.ScreenPx = ArtSize, ScreenPx
C.ART_SIZES = ART_SIZES

-- Things that only exist on newer clients: tried, and skipped if missing.
local function Try(f, ...) if f then return pcall(f, ...) end end

-- In a fight, or about to be: as combat starts (PLAYER_REGEN_DISABLED, when
-- First Aid Kit opens itself) the player is already in combat but frames
-- can still change for a moment. Anything that would hide at the end of an
-- animation must hide at once then: by the time the animation ends, combat
-- won't let it, and it pops back up instead.
local function Fighting()
    if InCombatLockdown() then return true end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end
U.Fighting = Fighting

-- Slots part-way through sliding out or in: [btn] = its kit (see SlideTo).
local sliding = {}

-- Any of this kit's slots sliding right now.
function Kit:Sliding()
    for _, k in pairs(sliding) do
        if k == self then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Glows: one clock pulses every glow of every kit.
---------------------------------------------------------------------------

local GLOW_HALF = 0.7
C.glows = C.glows or setmetatable({}, { __mode = "k" })
C.glowClock = C.glowClock or CreateFrame("Frame")
C.glowClock:SetScript("OnUpdate", function()
    local t = GetTime() % (GLOW_HALF * 2) / GLOW_HALF
    local k = t <= 1 and t or (2 - t)
    k = 0.5 - 0.5 * math.cos(k * math.pi)
    local alpha = 0.35 + 0.65 * k
    for g in pairs(C.glows) do
        if g:IsShown() then g:SetAlpha(alpha) end
    end
end)

---------------------------------------------------------------------------
-- Saved settings every kit has. A kit's own defaults go on top.
---------------------------------------------------------------------------

C.BASE_DEFAULTS = {
    point = { "CENTER", "CENTER", 0, -160, "ui" },
    scale = 1,
    kitSize = 1,
    buttonSize = 1, -- the slots' buttons, in their places (1: as made)
    spread = 1,     -- the slots' distance from the center icon (1: as made)
    shown = true,          -- false: the whole kit is hidden (settings or the shared minimap menu)
    locked = false,
    edgeTuck = true,       -- false: on a screen edge on its own the kit stays fully out (Kit Dock v27)
    fadeIdle = false,
    fadeOpen = false,      -- the open kit fades too, once the mouse has been off it a while
    fadeOpenAfter = 5,     -- how long, in seconds
    fadeAmount = 0.4,      -- how visible the slots stay when faded (the kit button stays halfway to full)
    tooltipDefault = false, -- slot tooltips in the game's usual spot instead of beside the slot
    hideInCombat = false,
    chatNotices = true,    -- false: the kit's own notices stay out of chat (slash commands still answer)
    minimapButton = true,
    minimapAngle = 200,    -- (before v19; carried into minimapIcon.minimapPos once)
    facing = "up",         -- which way the layout points while the kit floats: up, down, left, right
    flyoutHide = 0.5,      -- seconds a drawer stays open in combat after the mouse leaves it
    barGap = 4,            -- room between the buttons on a bar (v23)
    -- The radial, for controllers (v39): on, the stick it's picked with
    -- ("right" or "left"), the camera held still while picking, its size,
    -- the buttons' names under them.
    radial = { on = true, stick = "right", camera = true, scale = 1, names = true },
    -- The reminder panel (v21): its look and spot are shared by every kit, so
    -- each kit keeps a copy and the one changed last wins (see C.SyncPanel).
    -- x, y: its starting corner from the screen's centre, in UIParent units.
    -- on: this kit's own (whether its reminders go there), never shared.
    reminderPanel = {
        on = false,
        layout = "row",        -- "row": so many across, then a new row; "column": so many down
        perRow = 8, perCol = 8,
        corner = "TOPLEFT",    -- where it starts filling, and the corner x, y are for
        middle = true,         -- each row (column) grows out from the middle of the box
        size = 1,              -- its buttons (1: a full slot at 100%)
        gap = 4,               -- between its buttons
        grid = 16, snap = true, -- placing it (as SSBT's grid)
        stamp = 0,
    },
    panelSlots = {},       -- [slotKey] = true: with this kit's panel on, it shows there while the kit is closed (unless pinned, without cfg.panelPinned)
}

C.BASE_CHAR = {
    pinned = {}, -- [slotKey] = true: out even with the kit closed
    picks = {},  -- [slotKey] = what the slot holds, when you chose it
    order = {},  -- [slotKey] = { value, ... } your order for that slot's flyout
    -- Bars (v23): { { x, y, dir = "row" | "col", keys = { slotKey, ... } }, ... }
    -- x, y: the bar's middle from the screen's centre, in UIParent units.
    bars = {},
}

---------------------------------------------------------------------------
-- Making a kit
--
-- cfg (the kit's description):
--   addon         the kit addon's folder name
--   key           short key for Kit Dock ("wk")
--   name          "Warlock Kit"
--   prefix        frame name prefix and saved-variable stem ("WarlockKit")
--   color         hex colour for chat ("9482c9")
--   media         the kit's media folder (rings, masks, glows)
--   db, charDb    saved variable names ("WarlockKitDB", "WarlockKitCharDB")
--   defaults, charDefaults   on top of the base ones
--   dock          ns.Dock (Kit Dock), or nil
--   edgesOnly     never joins the pin, only the screen edges
--   bars          true: the kit has an edit mode where its buttons can be
--                 dragged off it onto bars that always show (v23). Any slot
--                 that can be pinned can go on a bar (noBar: not this one)
--   zones         (with bars) the places on the kit itself a button can be
--                 dragged between, and put in any order, in edit mode:
--                 { key = "ring", label = "Ring", ring = 1 }
--                     the slots of cfg.ring[1]. Give that ring count = how
--                     many it usually holds (up to that many keep its usual
--                     spacing, more sit closer; it never moves further out),
--                     widest = the longest its arc may get, in degrees, and
--                     avoid = n for cfg.ring[n], a ring of small buttons it
--                     must leave room for. With nothing in the row zones it
--                     may reach right round the kit, but keeps to the far
--                     side from the line while its usual spacing fits (v34)
--                 { key = "row", label = "Under the line", y = -112, step = 45,
--                   keys = { slotKey, ... } }
--                     a centred row at y, step apart, starting with keys
--                 Each zone shows its area in edit mode: a ring's whole drop
--                 band shaded (v35, the kit's circle_mask and zone_ring art), a
--                 row's box. Only slots that start in a zone can be
--                 moved between zones. From v31 a zone can also have:
--                   small = true   its slots are small round buttons (22),
--                                  the other zones' full slots: a slot takes
--                                  the size of the zone it's in, and changes
--                                  as it moves (out of combat). On a bar
--                                  it's a full slot. Used only when a zone
--                                  has it
--                   only = { slotKey, ... }  just these slots can be dropped
--                                  in it (any other is offered the other
--                                  zones); one saved there goes back to the
--                                  zone it started in
--                   track = true   (a ring inside another one) its name
--                                  goes just beyond its buttons, out from the
--                                  middle of its arc
--   OnZones(kit, lists)  the zones' slots changed (and once at login):
--                 lists[zoneKey] = { slotKey, ... }, slots on bars included.
--                 The kit puts them in its own tables (the ring's keys, its
--                 row, the divider's "below", its edge columns)
--   alwaysHideInCombat  the kit always hides in combat (nothing on it is any use
--                 in a fight): no "Hide in combat" setting for it
--   kitSize, slotSize  (60, 37)
--   roundKit      the kit button is a round icon with a ring
--   kitRing, kitIconInset  art name for that ring ("kit_ring": kit_ring_32..256,
--                 covering the whole button) and how far in the icon sits
--   AfterBuild(kit)  once the kit and its slots exist (add extra buttons)
--   OnFacing(kit)    the layout direction changed (kit:Face(x, y) turns a
--                    spot the same way; kit:FaceDir("down") a direction)
--   slots         { slot, ... } (below)
--   ring          { keys = { slotKey, ... }, from = deg, to = deg, radius = r }
--                 (or a list of them)
--                 slots spread evenly along this arc round the kit (degrees,
--                 0 = right, 90 = up), evenly spaced as if all were there;
--                 when some are hidden the rest close up round the middle of
--                 the arc, gliding over
--   edgeCols      { { slotKey, ... }, ... } columns on a screen edge, from the edge in
--   EdgeExtraCol(kit, hypothetical, asOpen)  one more column after those (non-slot
--                 frames, like timers): { { frame = f, size = n }, ... }
--   extraFrames(kit)  those frames (any that can show), so they're scaled
--                 and glide along when the kit moves
--   boxFrames(kit)  (optional) other frames the kit places itself that show
--                 while closed (a pinned extra button): in a Kit Dock box
--                 they go in the box's row with its pinned slots
--   PlaceExtras(kit, angle)  place those frames off an edge: angle is nil
--                 normally, or the fan's direction while shrunk on the dock
--   PinSettings(kit, S)  more boxes in the Pinned buttons section
--   menuOrder     { slotKey, ... } the order slots are listed in the settings
--   minimapArt    full-size art for the minimap button (it has its own rim)
--   glowColor     { r, g, b } the kit's glow colour
--   edgeBeside    { slotKey, ... } small slots that sit right beside the kit
--                 button on a screen edge, along the edge: the ones showing
--                 take turns before (above / left of) and after it, working
--                 outward; leave them out of edgeCols
--   divider       { y, width, texture, below = { slotKey, ... }, edgeAfter = n }
--                 a line across the kit at y while it's open and any of the
--                 "below" slots show; on an edge, between column n and n + 1
--   optionsWindow true: settings open in the kit's own window (sections down
--                 the left, in the kits' panel look) instead of the game's
--                 options page; from v17 the game's page only has a button
--                 that opens the window
--   slash         { "/wk", "/warlockkit" }
--   bindingHeader "WARLOCKKIT" (as in Bindings.xml)
--   KitArt(kit), KitTooltip(kit), BeforeRefresh(kit), Tick(kit)
--                 (a refresh also runs BeforeRefresh and every slot's Update once
--                 as a trial, with kit.open flipped and kit.trial set, to work out
--                 the other layout; change frames only when kit.trial is nil)
--   OnCombatToggle(kit, open)  the kit button opened (true) or closed (false) the
--                 kit in combat: move or show the kit's own extra frames to match
--                 (the slots are already done; a refresh follows when combat ends)
--   OnShapes(kit)     after slot shapes / ring art are (re)applied
--   Busy(kit)         true while the kit shouldn't fade (fade when idle; not
--                 fade when left open, which you've left open on purpose)
--   OnFade(kit, faded, alpha)  on each step of a fade (it eases in and out):
--                 alpha is the slots' alpha right now (1 = not faded), so the
--                 kit's own extra frames can fade with them; faded is true
--                 while it's faded or on its way there
--   events        { EVENT = function(kit, ...) end }
--   unitEvents    { EVENT = { units = { "player" }, fn = function(kit, ...) end } }
--   Settings(kit, S)    the kit's own section of the settings panel
--   GeneralSettings(kit, S), CombatSettings(kit, S), LookSettings(kit, S)
--                       more settings in the General section (before its Combat
--                       part), at the end of that Combat part (v17), and at the
--                       end of Look. S.Subheader("text", when)
--                       starts a group inside a section; with when (a function),
--                       the settings window shows the group only while it's true.
--   FirstSettings(kit, S)  pages of the kit's own in the "Kit" group, right
--                       after General (v24)
--   panelPinned   true: a pinned slot's reminder shows in the reminder panel
--                 too (ticked for the panel), while the slot stays by the kit
--                 (v26). Otherwise pinned slots stay out of the panel.
--   buttonTable   true: the kit sets its buttons' pinning in a table of its own
--                 (S.Table, v24), so Kit Core leaves out its "Pinned buttons" page
--   Menu(kit, root)    the kit's own lines in its right-click menu, between
--                 "Pin in place" and "Settings" (root is the game's menu
--                 description: root:CreateCheckbox, root:CreateButton, ...;
--                 kit:MenuToggle(root, label, dbKey, after) adds an on/off line)
--   MenuAfterSettings(kit, root)  lines under "Settings" at the menu's foot
--                 (v27), e.g. a way straight to one settings page with
--                 kit:OpenOptions("page title")
--   Slash(kit, cmd, rest) true if it handled cmd;  helpLines { "..." }
--   minimapIcon   texture for the minimap button
--   radial        true: the kit can be used from a controller as a ring (v39,
--                 see "The radial"); its Bindings.xml lists
--                 CLICK <prefix>Radial:LeftButton
--   macroIcon     the icon for its gamepad bar macro (a file ID or icon name)
--
-- A slot:
--   key, label, pos = { x, y } (from the kit's centre, +y up)
--   grid          which way its flyout opens: "up", "down", "left", "right"
--   small         a small round button (22) instead of a full slot
--   rim           (small slots) on a screen edge or shrunk on the dock it
--                 sits on the kit's rim: toward the middle of the screen, or
--                 away from the pin
--   flyGap        extra room between the slot and its flyout (a sub below it)
--   OnDrop(kit, btn)   something was dropped on the slot (cursor item)
--   Setup(kit, btn)    once, after the slot is made (extra scripts)
--   noPin         can't be pinned (or put on a bar)
--   noBar         can be pinned, but not dragged onto a bar (v23)
--   tier          shrunk on the dock, lower tiers fan out nearest the button
--                 (before the pinned-first, slot-order rule)
--   binding       key binding label (default "Use <label>")
--   flyout        "right": right-click opens its flyout; "left": any click does
--   Choices(kit, btn)  the flyout's choices (out of combat; see LayoutFlyout)
--   assign        a click on the slot does its assigned choice: the last one
--                 you clicked in its flyout (saved), else default
--   default       the assigned choice's value until you pick one (or a function)
--   reorder       its flyout's choices (those with a value) can be dragged into
--                 your own order, saved per character
--   keepEmpty     with nothing to assign yet, the slot still shows (empty) rather
--                 than hiding (or a function deciding it)
--   Update(kit, btn)   out of combat: set its attributes; btn.hidden hides it
--   Paint(kit, btn)    cosmetic, any time: icon, count, glow, cooldown
--   Tooltip(kit, btn)  fill GameTooltip (already owned)
--   Pop(kit, btn)      true to show it with the kit closed (like a pin)
--   noPanel       never goes in the reminder panel (v21)
--   panelFlyout   its copy in the reminder panel opens the slot's drawer on
--                 right-click, out of combat (v32; see Kit:OpenFlyoutAt)
--   panelDefault  in the reminder panel unless you untick it (default: true
--                 for a slot with Pop, false for the rest)
--   OnAttribute(kit, btn, name, value)  a flyout choice changed an attribute
--   OnPick(kit, btn, value)             a flyout "pick" choice (out of combat)
--   radialAlt     Y on the slot, or on its drawer's choices, in the radial (v39):
--                 { label, ready(kit), macro(kit, btn, choice, target) }
--   sub = { key, label, Update(kit, sb), Paint(kit, sb), Tooltip(kit, sb) }
--         a small round button on the slot's corner (below = true: under the
--         slot instead, except on a screen edge, where it's on the corner)
---------------------------------------------------------------------------

function C.NewKit(cfg)
    local self = setmetatable({}, Kit)
    self.cfg = cfg
    self.key, self.name, self.prefix = cfg.key, cfg.name, cfg.prefix
    self.media = cfg.media
    self.Dock = cfg.dock
    self.KIT = cfg.kitSize or 60
    self.BTN = cfg.slotSize or 37
    self.slots, self.slotByKey, self.order = {}, {}, {}
    for i, s in ipairs(cfg.slots) do
        self.slotByKey[s.key] = s
        self.order[s.key] = i
    end
    self.open, self.hovering = false, 0
    self.flyouts = {}
    self.snap = {} -- [true] = the open layout, [false] = the closed one (see StoreSnap)

    local events = CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)

    -- Key binding labels (the kit's Bindings.xml names the buttons).
    local H = cfg.bindingHeader
    if H then
        _G["BINDING_HEADER_" .. H] = cfg.name
        _G["BINDING_NAME_" .. H .. "_TOGGLE"] = Loc["Open / close the kit"]
        for _, slot in ipairs(cfg.slots) do
            _G["BINDING_NAME_CLICK " .. cfg.prefix .. "Slot_" .. slot.key .. ":LeftButton"] =
                slot.binding or (Loc["Use %s"]):format(slot.label:lower())
        end
    end
    if H and cfg.radial then
        _G["BINDING_NAME_CLICK " .. cfg.prefix .. "Radial:LeftButton"] = Loc["Radial (controller)"]
    end
    _G[cfg.prefix .. "_Toggle"] = function() self:Toggle() end
    _G[cfg.prefix .. "_OnCompartmentClick"] = function() self:OpenSettings() end

    if cfg.slash then
        local id = cfg.prefix:upper()
        for i, s in ipairs(cfg.slash) do _G["SLASH_" .. id .. i] = s end
        SlashCmdList[id] = function(msg) self:Slash(msg) end
    end
    return self
end

-- Chat messages. With "Chat messages" off in settings, only replies to a
-- slash command (and force, for something that's gone wrong) get through.
function Kit:Print(msg, force)
    if self.trial then return end -- (a trial layout says nothing)
    if not force and not self.inSlash and self.db and self.db.chatNotices == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. (self.cfg.color or "ffd100") .. "[" .. self.name .. "]|r " .. msg)
end

-- Right-click and shift-right-click run through the secure template's custom
-- action types; kept from firing twice in a row.
function Kit:Debounced()
    local now = GetTime()
    if now - (self.lastCustom or 0) < 0.2 then return false end
    self.lastCustom = now
    return true
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local function DefaultAnchor(owner)
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, owner)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
end

-- Slot, sub and flyout tooltips sit beside what you're hovering, or where the
-- game puts its own ("Default tooltip position"). The kit button's always
-- goes in the game's spot.
function Kit:TipOwner(owner)
    if self.db.tooltipDefault then DefaultAnchor(owner) else GameTooltip:SetOwner(owner, "ANCHOR_RIGHT") end
end

-- Hovering the kit button, a slot or a sub. Leaving hides the tooltip,
-- unless the kit's slots are sliding: then the tooltip stays as it is until
-- they've settled (SettleTip), so it doesn't flicker as slots pass under a
-- still pointer.
function Kit:Hover(on)
    self.hovering = math.max(0, self.hovering + (on and 1 or -1))
    self:ArmOpenFade()
    self:ApplyFade()
    if not on and not self:Sliding() then GameTooltip:Hide() end
end

-- Show a frame's tooltip when it's hovered, but not while the kit's slots are
-- sliding (they'd pass under the pointer one after another). frame.kcTip is
-- kept for SettleTip.
function Kit:HoverTip(frame, show)
    frame.kcKit, frame.kcTip = self, show
    frame:SetScript("OnEnter", function(b)
        self:Hover(true)
        if not self:Sliding() then show(b) end
    end)
    frame:SetScript("OnLeave", function() self:Hover(false) end)
end

-- The slides are over: the tooltip for whatever of this kit is under the
-- pointer now, or none if that's nothing of the kit's.
function Kit:SettleTip()
    if self:Sliding() then return end
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = foci and foci[1] or (GetMouseFocus and GetMouseFocus()) or nil
    if focus and focus.kcKit == self and focus.kcTip and focus:IsVisible() then
        focus.kcTip(focus)
        return
    end
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if owner and owner.kcKit == self then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Glows
---------------------------------------------------------------------------

function Kit:AddGlow(frame, texture, sizeMul)
    local g = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    g:SetTexture(self.media .. texture)
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER")
    g:SetSize(frame:GetWidth() * sizeMul, frame:GetHeight() * sizeMul)
    g:Hide()
    C.glows[g] = true
    frame.glow, frame.glowMul = g, sizeMul
end

-- color: { r, g, b }, or the kit's glow colour.
function Kit:SetGlow(frame, on, color)
    if not frame.glow then return end
    if on then
        local c = color or self.cfg.glowColor or { 1, 0.82, 0.3 }
        frame.glow:SetVertexColor(c[1], c[2], c[3])
        if not frame.glow:IsShown() then frame.glow:Show() end
    elseif frame.glow:IsShown() then
        frame.glow:Hide()
    end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

function Kit:MakeItemButton(name, parent, secure)
    local base = secure and "SecureActionButtonTemplate" or nil
    local ok, b = pcall(CreateFrame, "Button", name, parent, (base and (base .. ", ") or "") .. "ItemButtonTemplate")
    if not ok or not b then
        b = CreateFrame("Button", name, parent, base)
    end
    b:SetSize(self.BTN, self.BTN)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local atlas = "bags-item-slot64"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        bg:SetAtlas(atlas)
    else
        bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end
    b.slotBg = bg

    local icon = b.icon or b.Icon or (name and _G[name .. "IconTexture"])
    local count = b.Count or (name and _G[name .. "Count"])
    if icon and count then
        b.icon, b.count = icon, count
    else
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    end
    b.border = b:CreateTexture(nil, "ARTWORK", nil, 7)
    b.border:SetTexture(self.media .. "slot_border")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    if secure then
        -- Act on the button's release only, mouse or key binding alike, so
        -- a flyout opened by a click isn't shut again by the same click.
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("useOnKeyDown", false)
    end
    return b
end

function Kit:RingArt(b)
    return self.media .. "ring_slot_" .. ArtSize(ScreenPx(b, b:GetWidth() + 2), ART_SIZES)
end

function Kit:SmallRingArt(b)
    return self.media .. "ring_prof_" .. ArtSize(ScreenPx(b, b:GetWidth()), PROF_RING_SIZES)
end

-- Key binding labels, shortened the way the default action bars show them.
local function ShortKey(key)
    local t = (GetBindingText and GetBindingText(key, true)) or key
    t = t:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"):gsub("META%-", "m-")
    t = t:gsub("Mouse Button ", "M"):gsub("BUTTON", "M"):gsub("Middle Mouse", "M3")
    t = t:gsub("Num Pad ", "N"):gsub("NUMPAD", "N")
    t = t:gsub("Mouse Wheel Up", "WU"):gsub("Mouse Wheel Down", "WD")
    t = t:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
    -- Chinese clients spell them out too.
    t = t:gsub("鼠标滚轮向上滚动", "WU"):gsub("鼠标滚轮向下滚动", "WD")
    t = t:gsub("鼠标中键", "M3"):gsub("鼠标按键", "M"):gsub("数字键盘", "N")
    return t
end

function Kit:UpdateHotkeys()
    for _, btn in pairs(self.slots) do
        if btn.hotkey then
            local key = GetBindingKey("CLICK " .. btn:GetName() .. ":LeftButton")
            btn.hotkey:SetText(key and ShortKey(key) or "")
        end
    end
end

-- The round look (gold ring) for a full-size slot. Slots are always round
-- (the square option went in v14); calling it again refreshes the ring art
-- for the slot's size on screen. (A second argument, from older kits, is
-- ignored.)
function Kit:ApplyShape(b)
    if b.isSmall then return end
    local MASK = self.media .. "circle_mask"
    if b.roundParts then
        b.roundParts.ring:SetTexture(self:RingArt(b), nil, nil, "LINEAR")
        return
    end
    b.isRound = true
    local mask = b:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", 1, -1)
    mask:SetPoint("BOTTOMRIGHT", -1, 1)
    local slotMask = b:CreateMaskTexture()
    slotMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    slotMask:SetPoint("TOPLEFT", 1, -1)
    slotMask:SetPoint("BOTTOMRIGHT", -1, 1)
    local ring = b:CreateTexture(nil, "OVERLAY", nil, 6)
    ring:SetTexture(self:RingArt(b), nil, nil, "LINEAR")
    ring:SetPoint("TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", 1, -1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(self.media .. "glow_ring")
    hl:SetBlendMode("ADD")
    hl:SetPoint("CENTER")
    hl:SetSize(b:GetWidth() * 1.35, b:GetHeight() * 1.35)
    b.roundParts = { mask = mask, slotMask = slotMask, ring = ring, hl = hl, masked = true }
    b.icon:AddMaskTexture(mask)
    if b.slotBg then b.slotBg:AddMaskTexture(slotMask) end
    for _, t in ipairs({ b.border, b.IconBorder, b.GetNormalTexture and b:GetNormalTexture(),
            b.GetHighlightTexture and b:GetHighlightTexture(), b.GetPushedTexture and b:GetPushedTexture() }) do
        if t and t ~= hl then t:SetAlpha(0) end
    end
    if b.glow then
        b.glow:SetTexture(self.media .. "glow_ring")
        b.glow:SetSize(b:GetWidth() * 1.6, b:GetHeight() * 1.6)
        b.glowMul = 1.6
    end
    if b.hotkey then
        b.hotkey:ClearAllPoints()
        b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -4)
    end
    if b.pin then
        b.pin:ClearAllPoints()
        b.pin:SetPoint("CENTER", b, "CENTER", -11, 11)
    end
    if b.sel then b.sel:SetTexture(self.media .. "glow_ring") end
    if b.cooldown then
        Try(b.cooldown.SetSwipeTexture, b.cooldown, MASK)
        Try(b.cooldown.SetUseCircularEdge, b.cooldown, true)
    end
end

-- The small round look (22 across, gold ring), for small slots and the
-- buttons on a slot's corner. From v31 it can be called again on a slot
-- that has been full size since (SetSlotSmall): its small parts are made
-- the first time and shown again after that, and where its icon sat as a
-- full slot is kept, to go back to.
function Kit:MakeSmallRound(b)
    if b.icon and not b.iconFull then
        local pts = {}
        for i = 1, (b.icon.GetNumPoints and b.icon:GetNumPoints() or 0) do pts[i] = { b.icon:GetPoint(i) } end
        b.iconFull = { pts = pts, tc = { b.icon:GetTexCoord() } }
    end
    b:SetSize(22, 22)
    b.isSmall = true
    if b.slotBg then b.slotBg:Hide() end
    if b.border then b.border:SetAlpha(0) end
    for _, t in ipairs({ b.IconBorder, b.GetNormalTexture and b:GetNormalTexture(),
            b.GetHighlightTexture and b:GetHighlightTexture(), b.GetPushedTexture and b:GetPushedTexture() }) do
        if t then t:SetAlpha(0) end
    end
    if not b.icon then b.icon = b:CreateTexture(nil, "ARTWORK") end
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0, 1, 0, 1)
    if not b.roundMask then
        local mask = b:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(b.icon)
        b.roundMask = mask
    end
    if not b.roundMasked then
        b.icon:AddMaskTexture(b.roundMask)
        b.roundMasked = true
    end
    if not b.ring then b.ring = b:CreateTexture(nil, "OVERLAY", nil, 6) end
    b.ring:SetAllPoints()
    b.ring:SetTexture(self:SmallRingArt(b), nil, nil, "LINEAR")
    b.ring:Show()
    if not b.roundHl then
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(self.media .. "glow_ring")
        hl:SetBlendMode("ADD")
        hl:SetPoint("CENTER")
        hl:SetSize(30, 30)
        b.roundHl = hl
    end
    b.roundHl:Show()
    if b.hotkey then b.hotkey:Hide() end
    if b.count then b.count:Hide() end
end

-- A slot made small or full size after it was made (v31: it moved to a zone
-- of the other size). The look it isn't using is hidden, kept for when it
-- changes back; the one it is using is made the first time it's needed
-- (MakeSmallRound, ApplyShape). Its pin dot, glow and edit-mode highlight
-- change size with it, all at the Button size setting. Out of combat only
-- (the slots are secure); returns whether it changed.
function Kit:SetSlotSmall(btn, small)
    small = small and true or false
    if (btn.isSmall and true or false) == small or InCombatLockdown() then return false end
    local rp = btn.roundParts
    if small then
        if rp then
            rp.ring:Hide()
            rp.hl:Hide()
            if rp.masked then btn.icon:RemoveMaskTexture(rp.mask) rp.masked = nil end
        end
        self:MakeSmallRound(btn)
        btn.glowMul = 1.7
        if btn.pin then
            btn.pin:SetSize(8, 8)
            btn.pin:ClearAllPoints()
            btn.pin:SetPoint("CENTER", btn, "CENTER", -7, 7)
        end
    else
        if btn.ring then btn.ring:Hide() end
        if btn.roundHl then btn.roundHl:Hide() end
        if btn.roundMasked then btn.icon:RemoveMaskTexture(btn.roundMask) btn.roundMasked = nil end
        btn.isSmall = nil
        -- (its icon back where it sat as a full slot)
        local f = btn.iconFull
        btn.icon:ClearAllPoints()
        if f and #f.pts > 0 then
            for _, pt in ipairs(f.pts) do btn.icon:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
        else
            btn.icon:SetAllPoints()
        end
        if f then btn.icon:SetTexCoord(unpack(f.tc)) end
        if btn.slotBg then btn.slotBg:Show() end
        if btn.hotkey then btn.hotkey:Show() end
        if btn.count then btn.count:Show() end
        btn:SetSize(self.BTN, self.BTN)
        if btn.pin then btn.pin:SetSize(10, 10) end
        if rp then
            -- (full before: its round parts back, as ApplyShape first set them)
            rp.ring:Show()
            rp.hl:Show()
            if not rp.masked then btn.icon:AddMaskTexture(rp.mask) rp.masked = true end
            btn.glowMul = 1.6
            if btn.hotkey then
                btn.hotkey:ClearAllPoints()
                btn.hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -4)
            end
            if btn.pin then
                btn.pin:ClearAllPoints()
                btn.pin:SetPoint("CENTER", btn, "CENTER", -11, 11)
            end
        end
        self:ApplyShape(btn) -- (the first time: its round parts; after that, the ring's art for its size)
    end
    local w = (small and 22 or self.BTN) * (self.db.buttonSize or 1)
    btn:SetSize(w, w)
    if btn.glow then btn.glow:SetSize(w * (btn.glowMul or 1.6), w * (btn.glowMul or 1.6)) end
    if btn.roundParts and btn.roundParts.hl then btn.roundParts.hl:SetSize(w * 1.35, w * 1.35) end
    if small then btn.ring:SetTexture(self:SmallRingArt(btn), nil, nil, "LINEAR")
    elseif btn.roundParts then btn.roundParts.ring:SetTexture(self:RingArt(btn), nil, nil, "LINEAR") end
    if btn.kcEdit and btn.kcEdit.hl then
        local hw = w * (small and 1.7 or 1.6)
        btn.kcEdit.hl:SetSize(hw, hw)
    end
    return true
end

function Kit:ApplyShapes()
    for _, btn in pairs(self.slots) do
        self:ApplyShape(btn)
        if btn.ring then btn.ring:SetTexture(self:SmallRingArt(btn), nil, nil, "LINEAR") end
        if btn.sub then btn.sub.ring:SetTexture(self:SmallRingArt(btn.sub), nil, nil, "LINEAR") end
    end
    for _, fly in pairs(self.flyouts) do
        for _, b in ipairs(fly.buttons) do self:ApplyShape(b) end
    end
    if self.cfg.OnShapes then self.cfg.OnShapes(self) end
end

-- Icon, greyed (and dimmed) when it can't be used right now.
function U.SetIcon(btn, texture, greyed)
    btn.icon:SetTexture(texture)
    btn.icon:SetDesaturated(greyed and true or false)
    local v = greyed and 0.6 or 1
    btn.icon:SetVertexColor(v, v, v)
    btn.greyed, btn.noMana = greyed and true or false, nil
end

-- The spell a button casts on a plain left click, or nil: its "spell"
-- attribute, or for a macro the spell after its first /cast (the names in
-- the kits' macros come from spell IDs, so this works in any language).
function U.ButtonSpell(btn)
    local t = btn:GetAttribute("type")
    if t == "spell" then return btn:GetAttribute("spell") end
    if t ~= "macro" then return nil end
    local text = btn:GetAttribute("macrotext")
    for line in (text or ""):gmatch("[^\n]+") do
        local rest = line:match("^%s*/cast%s+(.+)$")
        if rest then
            rest = rest:gsub("%[.-%]", ""):gsub(";.*$", ""):match("^%s*(.-)%s*$")
            if rest ~= "" then return rest end
        end
    end
end

-- True when a spell is short of the power it costs (mana, mostly) right
-- now. Looked up as the rank you'd cast, so a cheaper rank still counts.
-- Anything the game won't tell an addon (a secret value) counts as fine.
function U.OutOfMana(spell)
    if not spell then return false end
    local key = type(spell) == "number" and spell or U.SpellByName(spell) or spell
    local f = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not f then return false end
    local ok, short = pcall(function()
        local _, noMana = f(key)
        return noMana and true or false
    end)
    return ok and short or false
end

---------------------------------------------------------------------------
-- The holder, the kit button and the secure header
---------------------------------------------------------------------------

-- A left click on the kit button in combat: switch every slot to the other
-- layout (where it goes and whether it shows, worked out out of combat and
-- left on each slot as attributes: kco* for the open layout, kcc* for the
-- closed one; see PushSnapshot), and close the flyouts, which belong to the
-- layout being left. Out of combat this does nothing: the click opens the
-- kit the usual way (animated, with the dock told). "kcready" is 0 when
-- this kit has no layouts to switch to (the kit open on the pin, or parked
-- in Kit Dock's box). A kit shrunk on the pin opens in its own slice there,
-- its slots fanned out in rings of 4 (from v8). Whether
-- it's combat comes from a state driver on the button itself ("kcincombat",
-- registered in BuildKit), which the game keeps right however early or late
-- combat's events arrive.
-- Switch the slots to the other layout. "kit" is the kit button's handle.
local TOGGLE_BODY = [[
    local want = "o"
    if kit:GetAttribute("kcisopen") == 1 then want = "c" end
    if want == "o" then kit:SetAttribute("kcisopen", 1) else kit:SetAttribute("kcisopen", 0) end
    for i = 1, NFLY do FLYOUTS[i]:Hide() end
    for i = 1, NSLOT do
        local b = SLOTS[i]
        if b:GetAttribute("kcbar") == 1 then
            -- (on a bar: it stays where it is, shown)
        elseif b:GetAttribute("kc" .. want .. "show") == 1 then
            b:ClearAllPoints()
            b:SetPoint("CENTER", kit, "CENTER", b:GetAttribute("kc" .. want .. "x") or 0, b:GetAttribute("kc" .. want .. "y") or 0)
            b:Show()
        else
            b:Hide()
        end
    end
]]
local KIT_PRE = [[
    if button ~= "LeftButton" or down then return end
    if self:GetAttribute("state-kcincombat") ~= "yes" then return end
    if self:GetAttribute("kcready") ~= 1 then return end
    local kit = self
]] .. TOGGLE_BODY

-- Moving the kit button in combat. Snippets only run from a few scripts
-- (OnClick among them, not OnMouseDown or OnMouseUp), and a click only
-- counts if you let go over the button you pressed. So in combat an unseen
-- secure "grip" button lies over the kit button (shown as combat starts,
-- see OnEvent), taking its left clicks on the press and on the release:
--   press    note where the mouse is (as a fraction across the holder, which
--            covers the screen) and, if the kit can move, stretch the grip
--            over the whole screen, so wherever you let go is still over it.
--   release  shrink the grip back onto the kit button. If the mouse moved
--            far enough, move the button by as much, kept on screen (its
--            slots are anchored to it, so they come too). If it hardly
--            moved, it was a click: open or close the kit (TOGGLE_BODY).
-- "kcmovable" is 1 for a kit that can move (pushed out of combat, see
-- PushMoveInfo); "kcks" is the button's scale against the holder's. Where it
-- put the button is left in "kcdropx"/"kcdropy" (holder units): asked
-- straight after, the game still gives the button's old spot. Each step
-- is noted in "kcmovestep", so when a move doesn't happen the kit can say
-- which part the game didn't allow.
local GRIP_CLICK = [[
    if button ~= "LeftButton" then return end
    local kit = self:GetFrameRef("kckit")
    local h = owner:GetFrameRef("kcholder")
    if down then
        GRABX, GRABY = nil, nil
        kit:SetAttribute("kcmovestep", "down")
        local mx, my = h:GetMousePosition()
        if mx and my then
            GRABX, GRABY = mx, my
            kit:SetAttribute("kcmovestep", "down-ok")
        end
        if kit:GetAttribute("kcmovable") == 1 then
            self:ClearAllPoints()
            self:SetAllPoints(h)
        end
        return
    end
    local x0, y0 = GRABX, GRABY
    GRABX, GRABY = nil, nil
    self:ClearAllPoints()
    self:SetAllPoints(kit)
    local drag = false
    if x0 then
        local mx, my = h:GetMousePosition()
        local W, H = h:GetWidth(), h:GetHeight()
        local dx, dy = 0, 0
        if mx and my then dx, dy = (mx - x0) * W, (my - y0) * H end
        drag = dx * dx + dy * dy >= 64 -- (moved 8 or more: a drag, not a click)
        local l, b, w, t = kit:GetRect()
        if drag and kit:GetAttribute("kcmovable") == 1 then
            kit:SetAttribute("kcmovestep", "up-pos")
            if l then
                kit:SetAttribute("kcmovestep", "up-rect")
                local ks = kit:GetAttribute("kcks") or 1
                local half = w * ks / 2
                local ox, oy = (l + w / 2) * ks, (b + t / 2) * ks
                local cx, cy = ox + dx, oy + dy
                if cx < half then cx = half elseif cx > W - half then cx = W - half end
                if cy < half then cy = half elseif cy > H - half then cy = H - half end
                local pin = kit:GetAttribute("kconpin") == 1 and self:GetFrameRef("kcpin")
                if pin then
                    -- On the pin with other kits: move every kit on it by as
                    -- much (this one kept on screen), then the pin. The kits
                    -- go to their own new spots first, read before anything
                    -- moves, so they get there whether or not they were
                    -- following the pin; after combat the dock puts them back
                    -- on it.
                    local mdx, mdy = cx - ox, cy - oy
                    local moves = newtable()
                    for i = 1, self:GetAttribute("kcdockn") or 0 do
                        local f = self:GetFrameRef("kcdock" .. i)
                        local fl, fb, fw, ft
                        if f then fl, fb, fw, ft = f:GetRect() end
                        if fl then
                            local fs = f:GetAttribute("kcks") or 1
                            moves[#moves + 1] = f
                            moves[#moves + 1] = ((fl + fw / 2) * fs + mdx) / fs
                            moves[#moves + 1] = ((fb + ft / 2) * fs + mdy) / fs
                        end
                    end
                    for i = 1, #moves, 3 do
                        local f = moves[i]
                        f:ClearAllPoints()
                        f:SetPoint("CENTER", h, "BOTTOMLEFT", moves[i + 1], moves[i + 2])
                    end
                    local pl, pb, pw, pt = pin:GetRect()
                    if pl then
                        local ps = kit:GetAttribute("kcpinks") or 1
                        local px, py = (pl + pw / 2) * ps + mdx, (pb + pt / 2) * ps + mdy
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", h, "BOTTOMLEFT", px / ps, py / ps)
                        kit:SetAttribute("kcdropx", px)
                        kit:SetAttribute("kcdropy", py)
                        kit:SetAttribute("kcmovestep", "moved-pin")
                    end
                else
                    kit:ClearAllPoints()
                    kit:SetPoint("CENTER", h, "BOTTOMLEFT", cx / ks, cy / ks)
                    kit:SetAttribute("kcdropx", cx)
                    kit:SetAttribute("kcdropy", cy)
                    kit:SetAttribute("kcmovestep", "moved")
                end
            end
        end
    end
    if not drag and kit:GetAttribute("kcready") == 1 then
]] .. TOGGLE_BODY .. [[
    end
]]

function Kit:BuildKit()
    local cfg, P = self.cfg, self.prefix
    local holder = CreateFrame("Frame", P .. "Holder", UIParent, "SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    holder:SetFrameStrata("MEDIUM")
    self.holder = holder

    -- Runs the flyouts' open and close, and the kit button's in combat.
    local header = CreateFrame("Frame", P .. "Secure", holder, "SecureHandlerBaseTemplate")
    header:Execute([[ FLYOUTS = newtable() FLYSLOTS = newtable() NFLY = 0 SLOTS = newtable() NSLOT = 0 ]])
    self.header = header
    if C.Panel then C.Panel() end -- (the reminder panel, made once for every kit)

    -- The kit button is a secure button (with no action of its own) so its
    -- click can run a secure snippet that moves the slots (see KIT_PRE).
    local okk, kit = pcall(CreateFrame, "Button", P .. "Button", holder, "SecureActionButtonTemplate")
    if not okk or not kit then
        self.noSecureToggle = true
        kit = CreateFrame("Button", P .. "Button", holder)
    end
    kit:SetSize(self.KIT, self.KIT)
    kit:SetMovable(true)
    kit:SetClampedToScreen(true)
    kit:RegisterForDrag("LeftButton")
    kit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    kit:SetFrameStrata("MEDIUM")
    kit:SetFrameLevel(10)
    kit:Hide()
    kit.icon = kit:CreateTexture(nil, "ARTWORK")
    kit.icon:SetAllPoints()
    if cfg.roundKit then
        -- A round icon in a ring. With cfg.kitRing (art covering the whole
        -- button, like the other kits' rim) the icon sits inside it;
        -- otherwise a slot's gold ring, 3 in from the edge, so it's the same
        -- size on screen as the other kits' art.
        local inset = cfg.kitRing and (cfg.kitIconInset or 7) or 5
        kit.icon:ClearAllPoints()
        kit.icon:SetPoint("TOPLEFT", inset, -inset)
        kit.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
        local mask = kit:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(kit.icon)
        kit.icon:AddMaskTexture(mask)
        kit.shade = kit:CreateTexture(nil, "ARTWORK", nil, 2)
        kit.shade:SetAllPoints(kit.icon)
        kit.shade:SetColorTexture(0, 0, 0, 0.35)
        kit.shade:AddMaskTexture(mask)
        kit.ring = kit:CreateTexture(nil, "OVERLAY", nil, 6)
        if cfg.kitRing then
            kit.ring:SetAllPoints()
        else
            kit.ring:SetPoint("TOPLEFT", 3, -3)
            kit.ring:SetPoint("BOTTOMRIGHT", -3, 3)
        end
        kit.text = kit:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        kit.text:SetPoint("CENTER", 0, 1)
        kit.text:SetTextColor(1, 1, 1)
        kit.text:SetShadowOffset(1, -1)
    end
    kit.hl = kit:CreateTexture(nil, "HIGHLIGHT")
    kit.hl:SetTexture(self.media .. "glow_ring")
    kit.hl:SetBlendMode("ADD")
    kit.hl:SetAllPoints()
    kit.hl:SetAlpha(0.35)
    self.kit = kit
    self:AddGlow(kit, "glow_ring", 1.35)

    -- A divider line between the slots round the kit and a row below it.
    local d = cfg.divider
    if d then
        local dv = CreateFrame("Frame", P .. "Divider", holder)
        dv:SetSize(d.width or 200, 16)
        dv:SetFrameLevel(11)
        dv.tex = dv:CreateTexture(nil, "ARTWORK")
        dv.tex:SetPoint("CENTER")
        dv.tex:SetSize(d.width or 200, 16)
        dv.tex:SetTexture(self.media .. (d.texture or "divider"), nil, nil, "LINEAR")
        dv:SetPoint("CENTER", kit, "CENTER", 0, d.y)
        dv:Hide()
        local ag = dv:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
        a:SetDuration(0.2)
        dv.fadeIn = ag
        self.divider = dv
    end

    kit:SetScript("OnDragStart", function(b)
        if self.db.locked then return end
        if InCombatLockdown() then
            return
        end
        self:CloseFlyouts()
        GameTooltip:Hide()
        if self.Dock then self.Dock.DragStart(self.key) else
            b.moving = true
            b:StartMoving()
        end
    end)
    kit:SetScript("OnDragStop", function(b)
        if InCombatLockdown() then return end
        if self.Dock and self.Dock.dragging then
            self.Dock.DragStop(self.key)
            return
        end
        -- The game reports the end of a drag even when it never started one
        -- here (locked, or in combat): nothing moved, so nothing to save.
        if not b.moving then return end
        b.moving = nil
        b:StopMovingOrSizing()
        self:SavePosition()
        self:KeepOnScreen()
    end)
    kit:SetScript("OnClick", function(_, button)
        if button == "RightButton" and IsShiftKeyDown() then
            self:OpenSettings()
            return
        end
        if button == "RightButton" then
            self:OpenMenu()
            return
        end
        -- In combat the secure snippet (KIT_PRE) has already switched the
        -- slots, if it could; this only catches the kit up.
        if InCombatLockdown() then
            self:CombatToggled()
            return
        end
        if self.editing then return end -- (editing the layout: it stays open)
        self:SetOpen(not self.open)
    end)
    self:HoverTip(kit, function(b)
        DefaultAnchor(b)
        GameTooltip:AddLine(self.name)
        if cfg.KitTooltip then cfg.KitTooltip(self) end
        GameTooltip:AddLine(Loc["Left-click: open / close"], 1, 1, 1)
        if not self.db.locked then GameTooltip:AddLine(Loc["Drag: move"], 1, 1, 1) end
        GameTooltip:AddLine(Loc["Right-click: menu   Shift-right-click: settings"], 1, 1, 1)
        GameTooltip:Show()
    end)
    if not self.noSecureToggle then
        local okw = pcall(SecureHandlerWrapScript, kit, "OnClick", header, KIT_PRE)
        if not okw then
            self.noSecureToggle = true
        else
            Try(RegisterStateDriver, kit, "kcincombat", "[combat] yes; no")
            header:SetFrameRef("kcholder", holder)
            -- The grip (see GRIP_CLICK): over the kit button in combat, below
            -- the buttons a kit puts on it (those sit 6 or more levels up).
            local okg, grip = pcall(CreateFrame, "Button", P .. "Grip", kit, "SecureActionButtonTemplate")
            if okg and grip then
                grip:SetAllPoints(kit)
                grip:SetFrameLevel(kit:GetFrameLevel() + 1)
                grip:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
                grip:Hide()
                SecureHandlerSetFrameRef(grip, "kckit", kit)
                -- (these run after the snippet, and only follow along)
                grip:SetScript("OnMouseDown", function(_, mouse)
                    if mouse == "LeftButton" then self:NoteCombatPress() end
                end)
                grip:SetScript("OnMouseUp", function() self:StopGhost() end)
                grip:SetScript("OnClick", function(_, mouse, down) self:GripClicked(mouse, down) end)
                grip:SetScript("OnEnter", function() local f = kit:GetScript("OnEnter") if f then f(kit) end end)
                grip:SetScript("OnLeave", function() local f = kit:GetScript("OnLeave") if f then f(kit) end end)
                grip.kcKit, grip.kcTip = self, function() kit.kcTip(kit) end
                self.grip = grip
            end
            if not (okg and grip) or not pcall(SecureHandlerWrapScript, grip, "OnClick", header, GRIP_CLICK) then
                self.grip = nil
                self.noSecureMove = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- The kit button's right-click menu, at the cursor: Pin in place, the
-- kit's own lines (cfg.Menu), Settings. Uses the game's menu system; on a
-- client without it, right-click locks and unlocks as it used to.
---------------------------------------------------------------------------

function Kit:SetLocked(on)
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
    self.db.locked = on and true or false
    self.kit:SetAttribute("kcmovable", self:CanSecureMove() and 1 or 0)
    self:Print(self.db.locked and Loc["Pinned in place."] or Loc["Unpinned. Drag the kit to move it."])
    self:SettingsChanged()
end

-- An on/off line for a saved setting. after(kit) runs once it's changed.
function Kit:MenuToggle(root, label, key, after)
    root:CreateCheckbox(label,
        function() return self.db[key] and true or false end,
        function()
            self.db[key] = not self.db[key]
            if after then after(self) end
            self:SettingsChanged()
        end)
end

-- Where the kit lives: on the pin with the other kits, parked in the top
-- dock, or free where it stands. Only with Kit Dock v19 or newer, and not
-- for edges-only kits.
function Kit:PlacementMenu(root)
    local D = self.Dock
    if not (D and D.Pin and D.Park and D.Undock) or self.cfg.edgesOnly then return end
    local function where()
        if D.IsParked and D.IsParked(self.key) then return "top" end
        if D.IsDocked(self.key) then return "pin" end
        return "free"
    end
    local function Go(to)
        if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
        if to == "top" then D.Park(self.key)
        elseif to == "pin" then D.Pin(self.key)
        else D.Undock(self.key) end
    end
    local sub = root:CreateButton(Loc["Place"])
    sub:CreateRadio(Loc["On the pin"], function() return where() == "pin" end, function() Go("pin") end)
    sub:CreateRadio(Loc["Tuck box"], function() return where() == "top" end, function() Go("top") end)
    sub:CreateRadio(Loc["Free"], function() return where() == "free" end, function() Go("free") end)
end

function Kit:OpenMenu()
    GameTooltip:Hide()
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:SetLocked(not self.db.locked)
        return
    end
    MenuUtil.CreateContextMenu(self.kit, function(_, root)
        root:CreateTitle(self.name)
        self:PlacementMenu(root)
        root:CreateCheckbox(Loc["Pin in place"],
            function() return self.db.locked and true or false end,
            function() self:SetLocked(not self.db.locked) end)
        if self.cfg.bars then
            root:CreateButton(self.editing and Loc["Done editing layout"] or Loc["Edit layout"], function() self:ToggleEdit() end)
        end
        if self.cfg.Menu then self.cfg.Menu(self, root) end
        root:CreateDivider()
        root:CreateButton(Loc["Settings"], function() self:OpenSettings() end)
        if self.cfg.MenuAfterSettings then self.cfg.MenuAfterSettings(self, root) end
    end)
end

function Kit:SetKitArt()
    local kit = self.kit
    if kit.ring then
        local ring = self.cfg.kitRing
        local px = ArtSize(ScreenPx(kit, kit:GetWidth() - (ring and 0 or 6)), ART_SIZES)
        kit.ring:SetTexture(self.media .. (ring or "ring_slot") .. "_" .. px, nil, nil, "LINEAR")
    end
    if self.cfg.KitArt then self.cfg.KitArt(self) end
end

-- Whether the kit hides in combat: its setting, unless it's in a Kit Dock box
-- and asks to stay there (cfg.staysInBox).
function Kit:HidesInCombat()
    if self.parked and self.cfg.staysInBox then return false end
    return self.db.hideInCombat and true or false
end

function Kit:ApplyCombatHide()
    if InCombatLockdown() then self.pending = true return end
    if self:HidesInCombat() then
        Try(RegisterStateDriver, self.holder, "visibility", "[combat] hide; show")
    else
        Try(UnregisterStateDriver, self.holder, "visibility")
        self.holder:Show()
    end
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

-- Opening or closing a flyout from a slot, in combat too. "right":
-- right-click (shift-right-click pins); "left": any click but shift-right.
-- Acts on the release only and swallows the press, so the slot's own action
-- doesn't run on a click that's meant for the flyout.
-- Out of combat a flyout closes when you click anywhere else (insecure, see
-- GLOBAL_MOUSE_DOWN). In combat that isn't allowed, so it closes itself a
-- moment after the mouse leaves it and its slot instead.
-- In combat a flyout closes itself this long after the mouse leaves it: the
-- kit's "flyoutHide" setting, handed to the secure code as the header's
-- "kchide" attribute when combat starts.
local TOGGLE_PRE = [[
    local fly = self:GetFrameRef("kcfly")
    if not fly then return end
    if button == "RightButton" and IsShiftKeyDown() then return end
    if button == "RightButton" or self:GetAttribute("kcflymode") == "left" then
        if not down then
            local show = not fly:IsShown()
            for i = 1, NFLY do FLYOUTS[i]:Hide() end
            if show then
                fly:Show()
                if owner:GetAttribute("kccombat") then
                    fly:RegisterAutoHide(owner:GetAttribute("kchide") or 0.5)
                    fly:AddToAutoHide(self)
                end
            end
        end
        return false
    end
]]

-- A choice clicked (on the release): one that's assigned to its slot copies
-- its action onto the slot, so a plain click on the slot repeats it. Runs
-- before the choice's own action (which uses the choice's attributes, so
-- the order doesn't matter). The game only runs an after-click snippet when
-- the before-click one returns a message, so closing (for choices that ask
-- for it) goes through that message.
-- The flyout stays open otherwise.
local ASSIGN_KEYS = { "type", "spell", "item", "macrotext", "shift-type1", "shift-macrotext1" }
local CHOICE_PRE = [[
    if down then return end
    if self:GetAttribute("kcassign") then
        local slot = self:GetFrameRef("kcslot")
        slot:SetAttribute("type", self:GetAttribute("type"))
        slot:SetAttribute("spell", self:GetAttribute("spell"))
        slot:SetAttribute("item", self:GetAttribute("item"))
        slot:SetAttribute("macrotext", self:GetAttribute("macrotext"))
        slot:SetAttribute("shift-type1", self:GetAttribute("shift-type1"))
        slot:SetAttribute("shift-macrotext1", self:GetAttribute("shift-macrotext1"))
        slot:SetAttribute("kcvalue", self:GetAttribute("kcvalue"))
    end
    if self:GetAttribute("kcclose") then return nil, "close" end
]]
local CHOICE_POST = [[
    if message == "close" then
        for i = 1, NFLY do FLYOUTS[i]:Hide() end
    end
]]

function Kit:CreateSlot(slot)
    local btn = self:MakeItemButton(self.prefix .. "Slot_" .. slot.key, self.holder, true)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(12)
    btn.slot = slot
    if not slot.noPin then
        btn:SetAttribute("shift-type2", "kcpin")
        btn:SetAttribute("_kcpin", function(b)
            if self:Debounced() then self:TogglePin(b.slot.key) end
        end)
    end

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    Try(btn.cooldown.SetDrawEdge, btn.cooldown, false)

    btn.pin = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    btn.pin:SetTexture(self.media .. "pin_dot", nil, nil, "LINEAR")
    btn.pin:SetSize(10, 10)
    btn.pin:SetPoint("CENTER", btn, "CENTER", -13, 13)

    btn.hotkey = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    btn.hotkey:SetJustifyH("RIGHT")

    btn.note = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.note:SetPoint("TOP", btn, "BOTTOM", 0, -1)

    if slot.small then
        self:MakeSmallRound(btn)
        btn.pin:SetSize(8, 8)
        btn.pin:ClearAllPoints()
        btn.pin:SetPoint("CENTER", btn, "CENTER", -7, 7)
        self:AddGlow(btn, "glow_ring", 1.7)
    else
        self:AddGlow(btn, "glow_ring", 1.6)
        self:ApplyShape(btn)
    end

    btn:HookScript("OnHide", function(b)
        -- (hidden some other way part-way through a slide: done with it)
        if sliding[b] then
            sliding[b] = nil
            b.slideTarget, b.slideWait, b.slideA, b.closing = nil, nil, nil, nil
            b.slideP = nil
            if not InCombatLockdown() then b:SetScale(self.db.scale) end
            if not self:Sliding() and C_Timer and C_Timer.After then
                C_Timer.After(0, function() self:SettleTip() end)
            end
        end
    end)
    local dx, dy = slot.pos[1], slot.pos[2]
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.kit, "CENTER", dx, dy)
    btn.homeX, btn.homeY, btn.placedX, btn.placedY = dx, dy, dx, dy

    if slot.sub then self:AddSub(btn, slot.sub) end
    if slot.Choices then self:AddFlyout(btn) end

    self:HoverTip(btn, function(b) self:SlotTooltip(b) end)
    btn:HookScript("OnAttributeChanged", function(b, name, value)
        -- A choice from the flyout became this slot's (maybe in combat).
        if name == "kcvalue" and slot.assign and not b.updating and value ~= nil then
            self.cdb.picks[slot.key] = value
            for _, fb in ipairs(b.fly and b.fly.buttons or {}) do
                if fb.choice and fb.choice.value == value then b.assigned = fb.choice end
            end
            self:PaintSlot(b)
            if b.fly and b.fly:IsShown() then self:PaintFlyout(b.fly) end
        end
        if slot.OnAttribute then slot.OnAttribute(self, b, name, value) end
    end)
    if slot.OnDrop then
        btn:SetScript("OnReceiveDrag", function(b) slot.OnDrop(self, b) end)
    end
    if slot.Setup then slot.Setup(self, btn) end
    btn:Hide()
    -- The kit button's secure snippet moves and shows the slots (KIT_PRE).
    self.header:SetFrameRef("kcnewbtn", btn)
    self.header:Execute([[ NSLOT = NSLOT + 1 SLOTS[NSLOT] = self:GetFrameRef("kcnewbtn") ]])
    self.slots[slot.key] = btn
    btn.order = self.order[slot.key]
    return btn
end

function Kit:SlotTooltip(btn)
    local slot = btn.slot
    self:TipOwner(btn)
    if slot.Tooltip then slot.Tooltip(self, btn) else GameTooltip:AddLine(slot.label) end
    local hints = {}
    if slot.flyout == "left" then hints[#hints + 1] = Loc["Click: open"] end
    if slot.flyout == "right" then hints[#hints + 1] = slot.flyoutHint or Loc["Right-click: choose"] end
    if #hints > 0 or not slot.noPin then GameTooltip:AddLine(" ") end
    for _, h in ipairs(hints) do GameTooltip:AddLine(h, 0.3, 1, 0.4) end
    if btn.kcBar then
        GameTooltip:AddLine(Loc["On a bar: always shown"], 1, 0.82, 0)
    elseif not slot.noPin then
        GameTooltip:AddLine(self.cdb.pinned[slot.key] and Loc["Shift-right-click: stop always showing"]
            or Loc["Shift-right-click: always show"], 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- Slots slide out of the kit as it opens and back in as it closes (from
-- v7) by really moving, a little each frame, not with the game's
-- animations. Those only move the picture: a slot's cooldown numbers didn't
-- go with it, and stopping one part-way (opening and closing quickly)
-- snapped the slot to its real spot for a moment before the next began. A
-- slide that turns round part-way now carries on from where the slot is.
--   btn.slideP       0 in the kit, 1 at its spot
--   btn.slideTarget  where it's heading (0 or 1); btn.closing while it's 0
--   btn.slideWait    seconds left before it starts (the stagger)
--   btn.slideA       its fade (ApplyFade multiplies it in)
-- Out of combat only: they're finished as combat starts (see OnEvent).
local OPEN_TIME, CLOSE_TIME = 0.22, 0.18
local slider = CreateFrame("Frame")
slider:Hide()
C.slider = slider -- (for testing)

local function Ease(p) return 1 - (1 - p) * (1 - p) end -- (fast out, slow in)

-- Put a sliding slot where its progress says: part-way between the kit and
-- its spot, shrunk toward the kit, faded in its first part.
function Kit:SlideApply(btn)
    local p = btn.slideP or 1
    local e = Ease(p)
    local sc = 0.3 + 0.7 * e
    local x, y = btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0
    btn:SetScale(self.db.scale * sc)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.kit, "CENTER", x * e / sc, y * e / sc) -- (offsets are in its own, shrunk, units)
    btn.slideA = math.min(1, p * OPEN_TIME / 0.16)
    self:FadeSlot(btn)
end

-- The slide is over: the slot at its spot at full size, or hidden in the kit.
function Kit:FinishSlide(btn)
    sliding[btn] = nil
    if not self:Sliding() then
        -- (next frame, once the pointer has caught up with where things are)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() self:SettleTip() end) else self:SettleTip() end
    end
    local target = btn.slideTarget or 1
    btn.slideP, btn.slideTarget, btn.slideWait, btn.slideA = target, nil, nil, nil
    if InCombatLockdown() then return end
    btn:SetScale(self.db.scale)
    if not btn.kcBar then -- (on a bar: PlaceBars keeps it there)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", self.kit, "CENTER", btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0)
    end
    if target == 0 then
        btn.closing = nil
        btn:Hide()
    end
    self:ApplyFade()
end

-- Finish every slide now (combat is starting).
function Kit:FinishSlides()
    for btn, kit in pairs(sliding) do
        if kit == self then self:FinishSlide(btn) end
    end
end

function Kit:SlideTo(btn, target, delay)
    if InCombatLockdown() or btn.kcBar then return end -- (a button on a bar never slides into the kit)
    if self.Dock and self.Dock.StopTween then self.Dock.StopTween(btn) end -- (a dock glide left over)
    if btn.slideP == nil then btn.slideP = 1 - target end
    btn.slideTarget = target
    btn.slideWait = delay or 0
    btn.closing = target == 0 or nil
    sliding[btn] = self
    self:SlideApply(btn)
    slider:Show()
end

function Kit:IsSliding(btn) return sliding[btn] ~= nil end

slider:SetScript("OnUpdate", function(f, dt)
    if InCombatLockdown() then return end -- (finished as combat started; see FinishSlides)
    for btn, kit in pairs(sliding) do
        if (btn.slideWait or 0) > 0 then
            btn.slideWait = btn.slideWait - dt
        else
            local up = btn.slideTarget == 1
            local p = (btn.slideP or 0) + (up and dt / OPEN_TIME or -dt / CLOSE_TIME)
            if (up and p >= 1) or (not up and p <= 0) then
                kit:FinishSlide(btn)
            else
                btn.slideP = p
                kit:SlideApply(btn)
            end
        end
    end
    if not next(sliding) then f:Hide() end
end)

-- Slides go between the kit and wherever the slot actually sits (its home
-- spot, its place on the dock, or its column on a screen edge).
local function PlayClose(kit, btn, index, total)
    if InCombatLockdown() then return end
    -- (staggered when the whole kit closes; straight back from part-way)
    local atRest = not sliding[btn]
    kit:SlideTo(btn, 0, atRest and (total - index) * 0.02 or 0)
end

local function CancelClose(kit, btn)
    if btn.closing then kit:SlideTo(btn, 1, 0) end -- (back out from where it is)
end

-- A slot just shown as the kit opens: out from the kit.
function Kit:PlaySlide(btn, index)
    if InCombatLockdown() then return end
    btn.slideP = 0
    self:SlideTo(btn, 1, (self.slideDelay or 0) + index * 0.025)
end

-- A small round secure button on the slot's corner (away from the kit's
-- edge side when on a screen edge). A child of the slot, so it slides,
-- fades and hides with it.
local SUB_CORNER = { 16, -16 }
local SUB_EDGE = { left = { 16, -16 }, right = { -16, -16 }, top = { 16, -16 }, bottom = { 16, 16 } }

function Kit:AddSub(btn, sub)
    local sb = CreateFrame("Button", self.prefix .. "Sub_" .. sub.key, btn, "SecureActionButtonTemplate")
    sb:RegisterForClicks("AnyUp", "AnyDown")
    sb:SetAttribute("useOnKeyDown", false)
    sb:SetFrameLevel(btn:GetFrameLevel() + 4)
    sb.icon = sb:CreateTexture(nil, "ARTWORK")
    self:MakeSmallRound(sb)
    sb.cooldown = CreateFrame("Cooldown", nil, sb, "CooldownFrameTemplate")
    sb.cooldown:SetPoint("TOPLEFT", 2, -2)
    sb.cooldown:SetPoint("BOTTOMRIGHT", -2, 2)
    Try(sb.cooldown.SetSwipeTexture, sb.cooldown, self.media .. "circle_mask")
    Try(sb.cooldown.SetUseCircularEdge, sb.cooldown, true)
    Try(sb.cooldown.SetDrawEdge, sb.cooldown, false)
    sb:SetPoint("CENTER", btn, "CENTER", SUB_CORNER[1], SUB_CORNER[2])
    self:AddGlow(sb, "glow_ring", 1.7)
    sb.def, sb.parentBtn = sub, btn
    self:HoverTip(sb, function(b)
        self:TipOwner(b)
        if sub.Tooltip then sub.Tooltip(self, b) else GameTooltip:AddLine(sub.label) end
        GameTooltip:Show()
    end)
    sb:Hide()
    btn.sub = sb
    _G["BINDING_NAME_CLICK " .. sb:GetName() .. ":LeftButton"] = sub.binding or sub.label
end

local SUB_BELOW = 3 + 11 -- gap under the slot, plus half the sub

function Kit:PlaceSub(btn)
    local sb = btn.sub
    if not sb then return end
    local x, y
    if self.edgeSide then
        local c = SUB_EDGE[self.edgeSide]
        x, y = c[1], c[2]
    elseif sb.def.below then
        x, y = self:Face(0, -(btn:GetHeight() / 2 + SUB_BELOW))
    else
        local bs = self.db.buttonSize or 1 -- (on a smaller button, closer in)
        x, y = SUB_CORNER[1] * bs, SUB_CORNER[2] * bs
    end
    sb:ClearAllPoints()
    sb:SetPoint("CENTER", btn, "CENTER", x, y)
end

---------------------------------------------------------------------------
-- Flyouts: a slot's choices, out to one side of it. Secure, so they open
-- and close (and their choices work) in combat as well.
--
-- A choice: {
--   icon, label, tooltip = function(tip) end (or uses item / spell below),
--   item = itemID or spell = spellID   (for the tooltip)
--   attrs = { type = "spell", spell = ..., ["shift-type1"] = ..., ... }
--     the secure action, or:
--   pick = value       out of combat only: the slot's OnPick runs with it
--   set = value        sets the slot's "kcset" attribute (in combat too);
--                      the slot's OnAttribute sees it
--   setAttr = { name, value }   sets any attribute on the slot, in combat too
--   value, assign      (slots with assign = true) with attrs: clicking it does
--                      its action and makes it the slot's own, so a plain
--                      click on the slot repeats it; saved in picks[slot]
--   close              close the flyout after this choice
--   selected, dim, count   (values or functions; repainted any time).
--                      An assigned choice shows selected while it's the slot's.
-- }
-- A flyout stays open until it's toggled from its slot or you click
-- elsewhere (in combat: until the mouse has been off it for a moment).
---------------------------------------------------------------------------

function Kit:AddFlyout(btn)
    local slot = btn.slot
    local fly = CreateFrame("Frame", self.prefix .. "Fly_" .. slot.key, self.holder, "SecureHandlerBaseTemplate")
    fly:SetAllPoints(self.kit)
    fly:SetFrameStrata("HIGH")
    fly:Hide()
    fly.slotBtn, fly.buttons = btn, {}
    btn.fly = fly
    self.flyouts[slot.key] = fly

    -- A dark panel behind the choices, so they read clearly over the kit.
    local okp, pnl = pcall(CreateFrame, "Frame", nil, fly, "BackdropTemplate")
    if not okp or not pnl then pnl = CreateFrame("Frame", nil, fly) end
    pnl:SetFrameLevel(math.max(0, fly:GetFrameLevel()))
    if pnl.SetBackdrop then
        pnl:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        pnl:SetBackdropColor(0.04, 0.03, 0.05, 0.88)
        pnl:SetBackdropBorderColor(0.78, 0.64, 0.3, 0.9)
    else
        local t = pnl:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.04, 0.03, 0.05, 0.88)
    end
    -- The flyout frame itself covers its choices (LayoutFlyout sizes it),
    -- so "the mouse is over it" means over the choices.
    pnl:SetAllPoints(fly)
    fly.panel = pnl

    self.header:SetFrameRef("kcnew", fly)
    self.header:SetFrameRef("kcnewslot", btn)
    self.header:Execute([[
        NFLY = NFLY + 1
        FLYOUTS[NFLY] = self:GetFrameRef("kcnew")
        FLYSLOTS[NFLY] = self:GetFrameRef("kcnewslot")
    ]])
    SecureHandlerSetFrameRef(btn, "kcfly", fly) -- (a plain secure button has no SetFrameRef of its own)
    btn:SetAttribute("kcflymode", slot.flyout or "right")
    SecureHandlerWrapScript(btn, "OnClick", self.header, TOGGLE_PRE)

    fly:SetScript("OnShow", function(f)
        self.flyOpen = f
        self:PaintFlyout(f)
        self:ArmOpenFade()
        self:ApplyFade()
        if not InCombatLockdown() then
            if f.count == 0 then
                self:Print(f.nothing or Loc["Nothing to choose from."])
                f:Hide()
                return
            end
            for i, b in ipairs(f.buttons) do
                if i <= f.count then
                    b.flyAnim:Stop()
                    b.flyHold:SetDuration(0.001 + (i - 1) * 0.02)
                    b.flyAnim:Play()
                end
            end
        end
    end)
    fly:SetScript("OnHide", function(f)
        if self.flyOpen == f then self.flyOpen = nil end
        -- (opened from the slot's reminder: back beside the slot)
        if f.anchorTo then
            f.anchorTo = nil
            if not InCombatLockdown() then self:LayoutFlyout(f.slotBtn) end
        end
        self:ArmOpenFade()
        self:ApplyFade()
    end)
end

function Kit:FlyButton(fly, i)
    local b = fly.buttons[i]
    if b then return b end
    b = self:MakeItemButton(fly:GetName() .. i, fly, true)
    b:SetFrameLevel(fly.panel:GetFrameLevel() + 2)
    SecureHandlerWrapScript(b, "OnClick", self.header, CHOICE_PRE, CHOICE_POST)
    SecureHandlerSetFrameRef(b, "kcslot", fly.slotBtn)
    b:SetAttribute("_kcpick", function(btn)
        if self:Debounced() and btn.choice then self:Pick(fly.slotBtn, btn.choice.pick) end
    end)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    Try(b.cooldown.SetDrawEdge, b.cooldown, false)
    b.sel = b:CreateTexture(nil, "OVERLAY")
    b.sel:SetTexture(self.media .. "glow_ring")
    b.sel:SetBlendMode("ADD")
    b.sel:SetVertexColor(0.75, 0.55, 1)
    b.sel:SetPoint("CENTER")
    b.sel:SetSize(self.BTN * 1.5, self.BTN * 1.5)
    -- Flies out of the slot as the flyout opens (out of combat).
    local ag = b:CreateAnimationGroup()
    local back = ag:CreateAnimation("Translation")
    back:SetDuration(0.001)
    back:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(0)
    hold:SetToAlpha(0)
    hold:SetDuration(0.001)
    hold:SetOrder(1)
    local out = ag:CreateAnimation("Translation")
    out:SetDuration(0.18)
    out:SetSmoothing("OUT")
    out:SetOrder(2)
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.14)
    fade:SetOrder(2)
    local grow = ag:CreateAnimation("Scale")
    grow:SetScaleFrom(0.4, 0.4)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.18)
    grow:SetSmoothing("OUT")
    grow:SetOrder(2)
    b.flyAnim, b.flyBack, b.flyHold, b.flyOut = ag, back, hold, out
    -- (a cooldown's numbers don't go along with an animation: hidden for the
    -- moment the choice flies out)
    ag:SetScript("OnPlay", function() b.cooldown:SetAlpha(0) end)
    ag:SetScript("OnFinished", function() b.cooldown:SetAlpha(1) end)
    ag:SetScript("OnStop", function() b.cooldown:SetAlpha(1) end)
    b:SetScript("OnEnter", function(btn)
        self:TipOwner(btn)
        local c = btn.choice
        if c then
            if c.tooltip then c.tooltip(GameTooltip)
            elseif c.item then GameTooltip:SetItemByID(c.item)
            elseif c.spell then Try(GameTooltip.SetSpellByID, GameTooltip, c.spell)
            else GameTooltip:AddLine(c.label or "") end
            if c.hint then GameTooltip:AddLine(c.hint, 0.3, 1, 0.4, true) end
            if fly.slotBtn.slot.reorder and c.value ~= nil and not InCombatLockdown() then
                GameTooltip:AddLine(Loc["Drag: move it in this list"], 1, 0.82, 0)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    self:ApplyShape(b)
    -- Drag a choice along its flyout to change the order (out of combat).
    if fly.slotBtn.slot.reorder then
        b:SetMovable(true)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function(btn)
            if InCombatLockdown() or not (btn.choice and btn.choice.value ~= nil) then return end
            GameTooltip:Hide()
            btn:SetFrameLevel(fly.panel:GetFrameLevel() + 6)
            btn.dragging = true
            self:DragBegin(fly, btn)
            btn:StartMoving()
            btn:SetScript("OnUpdate", function(f, dt) self:DragTick(fly, f, dt) end)
        end)
        b:SetScript("OnDragStop", function(btn)
            if not btn.dragging then return end
            btn.dragging = nil
            btn:SetScript("OnUpdate", nil)
            btn:StopMovingOrSizing()
            Try(btn.SetUserPlaced, btn, false) -- (the game mustn't remember where it was dropped)
            btn:SetFrameLevel(fly.panel:GetFrameLevel() + 2)
            self:DropChoice(fly, btn)
        end)
    end
    fly.buttons[i] = b
    return b
end

-- Dragging a choice along its flyout: the others slide aside, live, to show
-- where everything will end up; letting go there saves the new order.
-- Dropped away from the flyout, nothing changes.

-- Where a frame's centre is, in the choices' units from the kit's centre.
function Kit:FromKit(f)
    local x, y = f:GetCenter()
    local kx, ky = self.kit:GetCenter()
    if not (x and kx) then return nil end
    local k = self.kit:GetEffectiveScale() / f:GetEffectiveScale()
    return x - kx * k, y - ky * k
end

function Kit:DragBegin(fly, dragged)
    fly.dragFrom, fly.dragTo = nil, nil
    for i = 1, fly.count or 0 do
        local b = fly.buttons[i]
        if b == dragged then fly.dragFrom = i end
        local p = fly.pts and fly.pts[i]
        if p then b.curX, b.curY = p[1], p[2] end
    end
    fly.dragTo = fly.dragFrom
end

-- Which spot the dragged choice is over: the nearest one, if it's close
-- enough; else its own.
function Kit:DragTarget(fly, dragged)
    local x, y = self:FromKit(dragged)
    if not x or not fly.pts then return fly.dragFrom end
    local to, best
    for i = 1, fly.count or 0 do
        local p = fly.pts[i]
        local d = (p[1] - x) ^ 2 + (p[2] - y) ^ 2
        if not best or d < best then best, to = d, i end
    end
    local reach = self.BTN * 1.2
    if best and best <= reach * reach then return to end
    return fly.dragFrom
end

function Kit:DragTick(fly, dragged, dt)
    if InCombatLockdown() or not fly.dragFrom then return end
    local from, to = fly.dragFrom, self:DragTarget(fly, dragged)
    fly.dragTo = to
    local k = math.min(1, (dt or 0) * 14)
    for i = 1, fly.count or 0 do
        local b = fly.buttons[i]
        if b ~= dragged then
            -- Its place once the dragged one moves from "from" to "to".
            local j = i
            if from < to and i > from and i <= to then j = i - 1
            elseif from > to and i >= to and i < from then j = i + 1 end
            local p = fly.pts[j]
            b.curX = (b.curX or p[1]) + (p[1] - (b.curX or p[1])) * k
            b.curY = (b.curY or p[2]) + (p[2] - (b.curY or p[2])) * k
            b:ClearAllPoints()
            b:SetPoint("CENTER", fly.anchorTo or fly.slotBtn, "CENTER", b.curX - (fly.sx or 0), b.curY - (fly.sy or 0))
        end
    end
end

function Kit:DropChoice(fly, dragged)
    if InCombatLockdown() then return end
    local slot = fly.slotBtn.slot
    local from, to = fly.dragFrom, self:DragTarget(fly, dragged)
    fly.dragFrom, fly.dragTo = nil, nil
    if from and to and from ~= to then
        local vals = {}
        for i = 1, fly.count or 0 do
            local b = fly.buttons[i]
            vals[i] = b.choice and b.choice.value
        end
        local v = table.remove(vals, from)
        table.insert(vals, to, v)
        self.cdb.order[slot.key] = vals
    end
    self:LayoutFlyout(fly.slotBtn) -- every choice back in line, in its (new) place
    if fly:IsShown() then self:PaintFlyout(fly) end
end

-- A slot's choices in your saved order (any not in it yet keep their place
-- after the ones that are).
function Kit:OrderChoices(slot, choices)
    local saved = slot.reorder and self.cdb.order[slot.key]
    if not saved then return choices end
    local rank, at = {}, {}
    for i, v in ipairs(saved) do rank[v] = i end
    for i, c in ipairs(choices) do at[c] = i end
    table.sort(choices, function(a, b)
        local ra = a.value ~= nil and rank[a.value] or (1000 + at[a])
        local rb = b.value ~= nil and rank[b.value] or (1000 + at[b])
        return ra < rb
    end)
    return choices
end

-- Keep a flyout on screen: flip it to the other side of its slot when it
-- would run off an edge (if that's better), then nudge what's still over.
-- pts are offsets from the kit centre, in the flyout's units.
function Kit:FitPoints(pts, sx, sy)
    local ps = (self.db.scale or 1) * UIParent:GetEffectiveScale()
    local kx, ky = self.kit:GetCenter()
    if not kx or #pts == 0 then return end
    local k = self.kit:GetEffectiveScale() / ps
    kx, ky = kx * k, ky * k
    local W = UIParent:GetWidth() * UIParent:GetEffectiveScale() / ps
    local H = UIParent:GetHeight() * UIParent:GetEffectiveScale() / ps
    local m = self.BTN / 2 + 10
    local function Bounds()
        local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
        for _, p in ipairs(pts) do
            x0, x1 = math.min(x0, kx + p[1]), math.max(x1, kx + p[1])
            y0, y1 = math.min(y0, ky + p[2]), math.max(y1, ky + p[2])
        end
        return x0 - m, x1 + m, y0 - m, y1 + m
    end
    local function Over(a, b, size) return math.max(0, -a) + math.max(0, b - size) end
    local x0, x1 = Bounds()
    if Over(x0, x1, W) > 0 then
        for _, p in ipairs(pts) do p[1] = 2 * sx - p[1] end
        local a0, a1 = Bounds()
        if Over(a0, a1, W) >= Over(x0, x1, W) then
            for _, p in ipairs(pts) do p[1] = 2 * sx - p[1] end -- no better: flip back
        end
    end
    local _, _, y0, y1 = Bounds()
    if Over(y0, y1, H) > 0 then
        for _, p in ipairs(pts) do p[2] = 2 * sy - p[2] end
        local _, _, a0, a1 = Bounds()
        if Over(a0, a1, H) >= Over(y0, y1, H) then
            for _, p in ipairs(pts) do p[2] = 2 * sy - p[2] end
        end
    end
    local bx0, bx1, by0, by1 = Bounds()
    local dx = (bx0 < 0 and -bx0) or (bx1 > W and W - bx1) or 0
    local dy = (by0 < 0 and -by0) or (by1 > H and H - by1) or 0
    if dx ~= 0 or dy ~= 0 then
        for _, p in ipairs(pts) do p[1], p[2] = p[1] + dx, p[2] + dy end
    end
end

-- Which way a slot's flyout grows: its own direction; on a screen edge,
-- toward the middle of the screen; in the fan on the dock, away from the kit.
local TOWARD_MIDDLE = { left = "right", right = "left", top = "down", bottom = "up" }
local function FanDir(sx, sy)
    local a = math.deg(math.atan2(sy, sx))
    if a > -45 and a <= 45 then return "right"
    elseif a > 45 and a <= 135 then return "up"
    elseif a > -135 and a <= -45 then return "down"
    else return "left" end
end

-- Out of combat: fill a slot's flyout with its choices and place them.
function Kit:LayoutFlyout(btn)
    local fly = btn.fly
    if not fly then return end
    local slot = btn.slot
    local choices = self:OrderChoices(slot, slot.Choices(self, btn) or {})
    while #choices > 24 do table.remove(choices) end
    fly.nothing = slot.nothing
    local sx, sy = btn.placedX or slot.pos[1], btn.placedY or slot.pos[2]
    local grid = slot.grid and self:FaceDir(slot.grid) or FanDir(sx, sy)
    -- Once the kit's own layout has been changed (v23), a slot's drawer opens
    -- to suit where it is now: out from the middle on a ring, down from a row.
    local zone = self.zonesCustom and self.zoneNow and self.zoneNow[slot.key]
    if zone then grid = zone.ring and FanDir(sx, sy) or self:FaceDir("down") end
    if self.compactAngle then grid = FanDir(sx, sy) end
    if self.edgeSide then grid = TOWARD_MIDDLE[self.edgeSide] end
    if btn.kcBar and btn.barGrid then grid = btn.barGrid end -- (on a bar: away from the bar's line)
    -- Opened from the slot's reminder (Kit:OpenFlyoutAt): beside that
    -- instead, toward the middle of the screen. Gone (the reminder's done its
    -- job, say a stone went on): the drawer closes and is the slot's again.
    local anchor = fly.anchorTo
    if anchor then
        local ax, ay
        if anchor:IsVisible() then ax, ay = self:FlyAnchorAt(anchor) end
        if not ax then
            fly.anchorTo, anchor = nil, nil
            if fly:IsShown() then fly:Hide() end
        end
        if ax then
            sx, sy = ax, ay
            local cx = UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
            local cy = UIParent:GetHeight() * UIParent:GetEffectiveScale() / 2
            local x, y = anchor:GetCenter()
            local es = anchor:GetEffectiveScale()
            local dx, dy = cx - x * es, cy - y * es
            if dx * dx + dy * dy > 1 then grid = FanDir(dx, dy) end
        end
    end
    local at = anchor or btn
    local BTN = self.BTN
    local step = BTN + 4
    local per = slot.perRow or 8
    local pts = {}
    for i = 1, #choices do
        local x, y
        local line, at = math.floor((i - 1) / per), (i - 1) % per
        local n = math.min(#choices - line * per, per)
        -- A sub under the slot (not on an edge, where it's on the corner)
        -- needs the flyout to clear it when it opens that way.
        local gap = BTN + 10
        if slot.flyGap and not anchor and not self.edgeSide and not btn.kcBar and grid == self:FaceDir("down") then gap = gap + slot.flyGap end
        if grid == "left" or grid == "right" then
            local dir = grid == "left" and -1 or 1
            x = sx + dir * (gap + at * step)
            y = sy - line * step
        else
            local dir = grid == "down" and -1 or 1
            x = sx + (at - (n - 1) / 2) * step
            y = sy + dir * (gap + line * step)
        end
        pts[i] = { x, y }
    end
    self:FitPoints(pts, sx, sy)

    for i, c in ipairs(choices) do
        local b = self:FlyButton(fly, i)
        b.choice = c
        -- Clear what the last choice in this spot set, then set this one's.
        for _, k in ipairs(b.attrKeys or {}) do b:SetAttribute(k, nil) end
        local keys = {}
        local function Set(k, v) b:SetAttribute(k, v) keys[#keys + 1] = k end
        if c.attrs then
            for k, v in pairs(c.attrs) do Set(k, v) end
        elseif c.pick ~= nil then
            Set("type", "kcpick")
        elseif c.set ~= nil or c.setAttr then
            Set("type", "attribute")
            Set("attribute-frame", btn)
            Set("attribute-name", c.setAttr and c.setAttr[1] or "kcset")
            Set("attribute-value", c.setAttr and c.setAttr[2] or c.set)
        end
        if c.assign and c.attrs then
            Set("kcassign", true)
            Set("kcvalue", c.value)
        end
        if c.close then Set("kcclose", true) end
        b.attrKeys = keys
        -- Anchored to the slot, not the kit, so the choices stay beside it
        -- when the kit button switches layouts in combat and the slot moves.
        local x, y = pts[i][1], pts[i][2]
        local dx, dy = x - sx, y - sy
        b:ClearAllPoints()
        b:SetPoint("CENTER", at, "CENTER", dx, dy)
        b.flyBack:SetOffset(-dx, -dy)
        b.flyOut:SetOffset(dx, dy)
        b:Show()
    end
    for i = #choices + 1, #fly.buttons do
        fly.buttons[i].choice = nil
        fly.buttons[i]:Hide()
    end
    fly.count = #choices
    fly.pts = pts
    fly.sx, fly.sy = sx, sy -- (where the slot was when the points were worked out)
    fly:SetScale(self.db.scale)

    if #choices > 0 then
        local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
        for _, p in ipairs(pts) do
            x0, x1 = math.min(x0, p[1]), math.max(x1, p[1])
            y0, y1 = math.min(y0, p[2]), math.max(y1, p[2])
        end
        local pad = BTN / 2 + 7
        fly:ClearAllPoints()
        fly:SetPoint("TOPLEFT", at, "CENTER", x0 - pad - sx, y1 + pad - sy)
        fly:SetPoint("BOTTOMRIGHT", at, "CENTER", x1 + pad - sx, y0 - pad - sy)
        fly.panel:Show()
    else
        fly:ClearAllPoints()
        fly:SetAllPoints(at)
        fly.panel:Hide()
    end
    if fly:IsShown() then self:PaintFlyout(fly) end
end

-- Out of combat: a slot whose flyout choices are assigned to it does what
-- its chosen one does (your pick, else its default, else the first).
-- Copies the same attributes a choice copies when you click it in combat.
function Kit:ApplyAssigned(btn)
    local slot = btn.slot
    local choices = slot.Choices(self, btn) or {}
    local want = self.cdb.picks[slot.key]
    if want == nil then want = Val(slot.default, self, btn) end
    local found, first
    for _, c in ipairs(choices) do
        if c.assign and c.attrs then
            first = first or c
            if c.value == want then found = c end
        end
    end
    local c = found or first
    btn.assigned = c
    btn.updating = true
    local a = c and c.attrs or {}
    for _, k in ipairs(ASSIGN_KEYS) do btn:SetAttribute(k, a[k]) end
    btn:SetAttribute("kcvalue", c and c.value or nil)
    btn.updating = nil
    if not c and not Val(slot.keepEmpty, self, btn) then btn.hidden = true end
end

-- Where a frame other than the slot sits, as the drawer's points count it:
-- from the kit's centre, in the drawer's units (see FitPoints).
function Kit:FlyAnchorAt(f)
    local x, y = f:GetCenter()
    local kx, ky = self.kit:GetCenter()
    if not (x and kx) then return nil end
    local ps = (self.db.scale or 1) * UIParent:GetEffectiveScale()
    local fe, ke = f:GetEffectiveScale(), self.kit:GetEffectiveScale()
    return (x * fe - kx * ke) / ps, (y * fe - ky * ke) / ps
end

-- A slot's drawer opened from somewhere else, out of combat (v32): its copy
-- in the reminder panel (slot.panelFlyout), or a kit's own reminder button
-- for it. It opens beside that frame, toward the middle of the screen, and
-- is the slot's own again once it closes. Again from the same frame: closes.
function Kit:OpenFlyoutAt(btn, anchor)
    local fly = btn and btn.fly
    if not (fly and anchor) or InCombatLockdown() then return end
    if fly:IsShown() and fly.anchorTo == anchor then fly:Hide() return end
    for _, f in pairs(self.flyouts) do
        if f:IsShown() then f:Hide() end
    end
    fly.anchorTo = anchor
    self:LayoutFlyout(btn)
    if fly.anchorTo == anchor then fly:Show() end
end

function Kit:LayoutFlyouts()
    for _, fly in pairs(self.flyouts) do self:LayoutFlyout(fly.slotBtn) end
end

-- Cosmetic, any time: icons, what's chosen, what can't be used, counts.
function Kit:PaintFlyout(fly)
    for i, b in ipairs(fly.buttons) do
        local c = i <= (fly.count or 0) and b.choice
        if c then
            U.SetIcon(b, Val(c.icon) or 134400, Val(c.dim))
            local sel = Val(c.selected)
            if sel == nil and c.assign then
                local a = fly.slotBtn.assigned
                sel = a and a.value == c.value
            end
            b.sel:SetShown(sel and true or false)
            local n = Val(c.count)
            b.count:SetText(n and n > 1 and n or "")
            if c.cooldown then U.SetCooldown(b.cooldown, c.cooldown()) else b.cooldown:Clear() end
            self:TintMana(b)
        end
    end
end

-- Out of combat; in combat a flyout closes from its own slot or a choice.
function Kit:CloseFlyouts()
    if InCombatLockdown() then return end
    for _, fly in pairs(self.flyouts) do
        if fly:IsShown() then fly:Hide() end
    end
end

-- A "pick" choice (out of combat): the slot decides what it means.
function Kit:Pick(btn, value)
    if InCombatLockdown() then return end
    local slot = btn.slot
    if slot.OnPick then
        slot.OnPick(self, btn, value)
    else
        self.cdb.picks[slot.key] = value
    end
    self:Refresh(false)
end

---------------------------------------------------------------------------
-- Painting (cosmetic, safe in combat)
---------------------------------------------------------------------------

function Kit:PaintSlot(btn)
    local slot = btn.slot
    btn.pin:SetShown(self.cdb.pinned[slot.key] and not btn.kcBar and true or false)
    btn.note:SetText("")
    if btn.count then btn.count:SetText("") end
    if slot.Paint then slot.Paint(self, btn) end
    local sb = btn.sub
    if sb and sb:IsShown() and sb.def.Paint then sb.def.Paint(self, sb) end
    self:TintMana(btn)
    if sb and sb:IsShown() then self:TintMana(sb) end
    if btn.twin then self:MirrorTwin(btn) end -- (its copy in the reminder panel)
end

-- A slot (or flyout choice) whose spell you can't afford turns red. Greyed
-- ones (unlearned, no pet, no shards and so on) stay grey.
local NO_MANA = { 0.9, 0.25, 0.25 }
function Kit:TintMana(b)
    if not (b and b.icon) then return end
    local short = not b.greyed and U.OutOfMana(U.ButtonSpell(b))
    if short then
        b.icon:SetVertexColor(NO_MANA[1], NO_MANA[2], NO_MANA[3])
    elseif b.noMana then
        local v = b.greyed and 0.6 or 1
        b.icon:SetVertexColor(v, v, v)
    end
    b.noMana = short or nil
end

-- Only the red tint, when mana changes (cheap: no repaint).
function Kit:PaintMana()
    if not self.built then return end
    for _, btn in pairs(self.slots) do
        if btn:IsShown() then
            self:TintMana(btn)
            if btn.sub and btn.sub:IsShown() then self:TintMana(btn.sub) end
        end
    end
    for _, fly in pairs(self.flyouts) do
        if fly:IsShown() then
            for i, b in ipairs(fly.buttons) do
                if i <= (fly.count or 0) then self:TintMana(b) end
            end
        end
    end
end

-- Fading eases rather than snapping: self.fadeT runs from 0 (full) to 1
-- (faded) over FADE_OUT seconds, and back over FADE_IN, a little each frame.
local FADE_OUT, FADE_IN = 0.5, 0.2

function Kit:ApplyFade()
    if not self.built then return end
    local target = self:FadeIdle() and 1 or 0
    if not self.fadeT then self.fadeT = target end
    if self.fadeT ~= target then
        local fader = self.fader
        if not fader then
            fader = CreateFrame("Frame")
            fader:Hide()
            fader:SetScript("OnUpdate", function(f, elapsed)
                local to = self:FadeIdle() and 1 or 0
                local t = self.fadeT
                if to > t then t = math.min(to, t + elapsed / FADE_OUT)
                else t = math.max(to, t - elapsed / FADE_IN) end
                self.fadeT = t
                if t == to then f:Hide() end
                self:PaintFade()
            end)
            self.fader = fader
        end
        fader:Show()
    end
    self:PaintFade()
end

-- The slots' alpha from the fade as it stands (1 = not faded).
function Kit:FadeNow()
    local t = self.fadeT or 0
    t = t * t * (3 - 2 * t) -- (eased: starts and ends gently)
    return 1 - t * (1 - self:FadeAlpha())
end

function Kit:PaintFade()
    for _, btn in pairs(self.slots) do self:FadeSlot(btn) end
    local a = self:FadeNow()
    self.kit:SetAlpha((1 + a) / 2)
    local fly = self.flyOpen
    if fly and fly:IsShown() then self.kit:SetAlpha(0.4) end
    if self.cfg.OnFade then self.cfg.OnFade(self, (self.fadeT or 0) > 0, a) end
end

-- How visible faded slots stay (Fade amount); the kit button stays halfway
-- between that and full, so it can still be found.
function Kit:FadeAlpha()
    return self.db.fadeAmount or 0.4
end

function Kit:FadeIdle()
    if self.qkbOpen or self.editing then return false end -- (binding keys, or editing the layout: everything at full)
    if self.openFaded then return true end
    return self.db.fadeIdle and not self.open and self.hovering == 0
        and not (self.cfg.Busy and self.cfg.Busy(self))
end

-- Fade when left open: back to full now, and start counting again if the kit
-- is open with the mouse off it and no drawer out. Anything that changes one
-- of those comes through here, so a count that's overtaken just does nothing.
function Kit:ArmOpenFade()
    self.openFaded = nil
    self.openFadeCount = (self.openFadeCount or 0) + 1
    if self.qkbOpen then return end
    if not self.db.fadeOpen or not self.open or self.hovering > 0 or self.flyOpen then return end
    if not (C_Timer and C_Timer.After) then return end
    local count = self.openFadeCount
    C_Timer.After(self.db.fadeOpenAfter or 5, function()
        if count ~= self.openFadeCount then return end
        self.openFaded = true
        self:ApplyFade()
    end)
end

-- One slot's alpha: faded (as far as the fade has got), dimmed while another slot's flyout is
-- open (so its choices stand out), times its slide's fade.
function Kit:FadeSlot(btn)
    local a = self:FadeNow()
    if btn.kcBar then a = 1 end -- (on a bar: always shown, so it doesn't fade with the kit)
    local fly = self.flyOpen
    if fly and fly:IsShown() and btn ~= fly.slotBtn then a = 0.3 end
    if btn.kcDragging then a = 0.35 end -- (being dragged in edit mode: a faint mark of where it would go)
    btn:SetAlpha(a * (btn.slideA or 1))
end

function Kit:PaintAll()
    if not self.built then return end
    for _, btn in pairs(self.slots) do
        -- (hidden with the kit closed but its copy in the reminder panel
        -- showing: painted too, for the copy to follow)
        if btn:IsShown() or (btn.twin and btn.twin:IsShown()) then self:PaintSlot(btn) end
    end
    for _, fly in pairs(self.flyouts) do
        if fly:IsShown() then self:PaintFlyout(fly) end
    end
    self:SetKitArt()
    self:ApplyFade()
end

---------------------------------------------------------------------------
-- Where the slots sit
---------------------------------------------------------------------------

function Kit:KitHalfUnits()
    -- (the size it's growing or shrinking to, if Kit Dock is gliding it: a
    -- kit stepping out of a box opens while it grows)
    local D = self.Dock
    local sc = D and D.ScaleOf and D.ScaleOf(self.kit) or self.kit:GetScale()
    return self.kit:GetWidth() * sc / 2 / self.db.scale
end

-- Which slots go in each column on a screen edge, from the edge in.
-- asOpen/hypothetical answer "what would show" (for the dock's spacing).
function Kit:EdgeCols(asOpen, hypothetical)
    local function on(btn)
        if btn.kcBar then return false end -- (on a bar: no place by the kit)
        if hypothetical then return (asOpen and not btn.hidden) or btn.wouldShow end
        if self.trial then return self.trial.vis[btn] and true or false end -- (what would show in that layout)
        return btn:IsShown() and not btn.closing
    end
    local cols = {}
    for _, keys in ipairs(self.cfg.edgeCols or {}) do
        local col = {}
        for _, key in ipairs(keys) do
            local btn = self.slots[key]
            if btn and on(btn) then col[#col + 1] = { frame = btn, size = btn.isSmall and 22 or self.BTN } end
        end
        cols[#cols + 1] = col
    end
    -- In a Kit Dock box the slots that sit beside the button on an edge
    -- (along it) would land on the box: a column of their own instead.
    if self.parked and self.cfg.edgeBeside then
        local col = {}
        for _, key in ipairs(self.cfg.edgeBeside) do
            local btn = self.slots[key]
            if btn and on(btn) then col[#col + 1] = { frame = btn, size = btn.isSmall and 22 or self.BTN } end
        end
        cols[#cols + 1] = col
    end
    if self.cfg.EdgeExtraCol then cols[#cols + 1] = self.cfg.EdgeExtraCol(self, hypothetical, asOpen) or {} end
    return cols
end

-- The kit's own extra frames (timers and such), if any.
function Kit:Extras()
    return self.cfg.extraFrames and self.cfg.extraFrames(self) or {}
end

-- Small "rim" slots: on the kit's rim, at this angle (degrees).
function Kit:PlaceRim(angle)
    local r = self:KitHalfUnits() - 3
    -- In a Kit Dock box the button is small: the rim slot sits just outside it
    -- instead of on it.
    if self.parked then r = self:KitHalfUnits() + 7 end
    local placed = false
    for _, btn in pairs(self.slots) do
        if btn.slot.rim and not btn.kcBar then
            self:PlaceAt(btn, r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)))
            if self:WouldShow(btn) then placed = true end
        end
    end
    return placed
end

function Kit:PlaceAt(f, x, y)
    if f.kcBar then -- on a bar: it has no place by the kit (PlaceBars puts it on its bar)
        if self.trial then self.trial.pos[f] = { f.placedX or 0, f.placedY or 0 } end
        return
    end
    if self.trial then -- a trial layout only notes where it would go
        self.trial.pos[f] = { x, y }
        return
    end
    if self.collect then -- in a Kit Dock box: noted, for the box's row (see PlaceSlots)
        if f:IsShown() and not f.closing then self.collect[#self.collect + 1] = f end
        return
    end
    if sliding[f] then -- (the slide puts it there; see SlideApply)
        f.placedX, f.placedY = x, y
        return
    end
    if f.placedX ~= x or f.placedY ~= y then
        -- (a dock glide still on its way to the old spot would finish there)
        if self.Dock and self.Dock.StopTween then self.Dock.StopTween(f) end
        f:ClearAllPoints()
        f:SetPoint("CENTER", self.kit, "CENTER", x, y)
        f.placedX, f.placedY = x, y
    end
end

-- The divider goes between two edge columns while the kit is open.
function Kit:EdgeDivAfter(asOpen)
    local d = self.cfg.divider
    return asOpen and d and d.edgeAfter or nil
end

-- The edgeBeside slots: either side of the kit button, along the edge.
-- The i-th one showing: odd before the button, even after, outward in pairs.
local BESIDE_GAP, BESIDE_STEP = 6, 26
function Kit:BesideSpot(side, i)
    local d = self:KitHalfUnits() + BESIDE_GAP + 11 + math.floor((i - 1) / 2) * BESIDE_STEP
    local sign = (i % 2 == 1) and -1 or 1
    if side == "left" or side == "right" then return 0, -sign * d end
    return sign * d, 0
end

-- In a Kit Dock box the button is small and the box sits around it, so
-- what shows (reminders, pinned slots) starts just past the box's inner edge.
local PARKED_INSET = 8

function Kit:PlaceEdge()
    local cols = self:EdgeCols(self.open, false)
    local half = self:KitHalfUnits()
    if self.parked then half = half + PARKED_INSET / self.db.scale end
    local pos, div = self.Dock.EdgeArrange(self.edgeSide, half, cols, self:EdgeDivAfter(self.open))
    for f, p in pairs(pos) do self:PlaceAt(f, p[1], p[2]) end
    local beside = not self.parked and self.cfg.edgeBeside -- (in a box: a column, see EdgeCols)
    if beside then
        local i = 0
        for _, key in ipairs(beside) do
            local btn = self.slots[key]
            if btn and not btn.hidden and not btn.kcBar then
                i = i + 1
                self:PlaceAt(btn, self:BesideSpot(self.edgeSide, i))
            end
        end
    end
    local RIM = { left = 0, right = 180, top = 270, bottom = 90 } -- toward the middle of the screen
    self:PlaceRim(RIM[self.edgeSide] or 0)
    -- Where the divider goes (kept for the combat switch, which has to put it
    -- there without a refresh); false when it keeps its usual spot.
    local spec = div and { x = div[1], y = div[2], w = div[4] and 16 or div[3], h = div[4] and div[3] or 16,
        tw = div[3], rot = div[4] and math.pi / 2 or 0 } or false
    if self.trial then
        self.trial.div = spec
        return
    end
    self.liveDiv = spec
    for _, btn in pairs(self.slots) do self:PlaceSub(btn) end
    local dv = self.divider
    if dv then
        dv:ClearAllPoints()
        if div then
            dv:SetPoint("CENTER", self.kit, "CENTER", div[1], div[2])
            dv:SetSize(div[4] and 16 or div[3], div[4] and div[3] or 16)
            dv.tex:SetSize(div[3], 16)
            dv.tex:SetRotation(div[4] and math.pi / 2 or 0)
        else
            dv:SetPoint("CENTER", self.kit, "CENTER", 0, self.cfg.divider.y)
        end
        dv.edged = true
    end
end

-- Back from an edge: the divider in its usual spot across the kit.
function Kit:UnEdgeDivider()
    local dv = self.divider
    if not dv or not dv.edged then return end
    dv.edged = nil
    self:FaceDivider()
end

-- How much room along the edge the kit takes (UI units).
function Kit:EdgeExtent(side, asOpen)
    local cols = self:EdgeCols(asOpen, true)
    local _, _, ext = self.Dock.EdgeArrange(side, self:KitHalfUnits(), cols, self:EdgeDivAfter(asOpen))
    if self.cfg.edgeBeside then
        -- Room for the slots beside the button that would show.
        local n = 0
        for _, key in ipairs(self.cfg.edgeBeside) do
            local btn = self.slots[key]
            if btn and not btn.kcBar and ((asOpen and not btn.hidden) or btn.wouldShow) then n = n + 1 end
        end
        if n > 0 then
            local pairsOut = math.ceil(n / 2)
            ext = math.max(ext, 2 * (self:KitHalfUnits() + BESIDE_GAP + 22 + (pairsOut - 1) * BESIDE_STEP))
        end
    end
    local any = next(self.slots) and select(2, next(self.slots))
    local k = any and (any:GetEffectiveScale() / UIParent:GetEffectiveScale()) or self.db.scale
    return ext * k
end

-- Where shown slots sit: their home spot round the kit; on a screen edge,
-- in columns toward the middle of the screen; shrunk on the dock, fanned
-- round the outside of the button in its own slice. Out of combat only.
-- Facing (the "Layout direction" setting): the whole layout turns so its
-- top points up, down, left or right. Down is the layout mirrored top to
-- bottom; left and right turn it on its side, with slots that read left to
-- right reading top to bottom.
local FACE = {
    up = function(x, y) return x, y end,
    down = function(x, y) return x, -y end,
    left = function(x, y) return -y, -x end,
    right = function(x, y) return y, -x end,
}
C.FACINGS = { "up", "down", "left", "right" }

-- The layout direction in use: the setting while floating; docked on the
-- pin with other kits, always up, so the merged layout stays as it was.
function Kit:Facing()
    local D = self.Dock
    if D and D.IsDocked and D.IsDocked(self.key) then return "up" end
    return FACE[self.db and self.db.facing] and self.db.facing or "up"
end

function Kit:Face(x, y)
    return FACE[self:Facing()](x, y)
end

function Kit:SetFacing(f)
    if not FACE[f] then return end
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
    self.db.facing = f
    self:Refresh(false)
    self:KeepOnScreen()
    if self.cfg.OnFacing then self.cfg.OnFacing(self) end
    self:SettingsChanged()
end

function Kit:Sideways()
    local f = self:Facing()
    return f == "left" or f == "right"
end

-- A direction ("up", "left", ...) in the layout, turned the way it faces.
local DIR_VEC = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
function Kit:FaceDir(dir)
    local v = DIR_VEC[dir]
    if not v then return dir end
    local x, y = self:Face(v[1], v[2])
    if x > 0.5 then return "right" elseif x < -0.5 then return "left" elseif y > 0.5 then return "up" end
    return "down"
end

-- cfg.ring: the slots that are there (not hidden) share the arc evenly.
-- Fills base[btn] = { x, y } (before facing).
function Kit:LayoutOneRing(ring, base, index)
    local avail = {}
    for _, key in ipairs(ring.keys) do
        local btn = self.slots[key]
        if btn and not btn.hidden and not btn.kcBar then avail[#avail + 1] = btn end -- (one on a bar leaves no gap)
    end
    -- The full ring's spacing, centred on the arc's middle: with fewer slots
    -- the whole set (ends included) gathers round the top.
    local n = #avail
    local step, radius, mid, round = self:RingGeo(ring, n, ring.count and self:BelowEmpty() or false)
    -- A ring that has gone right round the kit with no room to spare sends
    -- the small buttons it would cover to just outside it (still side by side).
    if round and ring.avoid then
        self.ringPush = self.ringPush or {}
        self.ringPush[ring.avoid] = radius + self.BTN / 2 + 15
    end
    local push = index and self.ringPush and self.ringPush[index]
    if push then
        step = step * radius / push
        radius = push
    end
    for i, btn in ipairs(avail) do
        local a = mid + (i - (n + 1) / 2) * step
        base[btn] = { math.floor(radius * math.cos(math.rad(a)) + 0.5), math.floor(radius * math.sin(math.rad(a)) + 0.5) }
    end
end

-- Is there nothing on the kit below the line (in its row zones)? lists: the
-- zones' slots (as they are, if not given).
function Kit:BelowEmpty(lists)
    if not (self.cfg.bars and self.cfg.zones) then return false end
    lists = lists or self:Zones()
    local any = false
    for _, z in ipairs(self.cfg.zones) do
        if z.y then
            any = true
            if #self:ZoneShown(lists[z.key]) > 0 then return false end
        end
    end
    return any
end

-- The part of the circle a ring has to leave free for another ring's
-- buttons (ring.avoid: the small buttons under the kit), in degrees,
-- opposite the ring's own middle. 0 when none of them are there.
function Kit:RingGap(ring)
    local other = ring.avoid and self:Rings()[ring.avoid]
    if not other then return 0 end
    local k = 0
    for _, key in ipairs(other.keys) do
        local btn = self.slots[key]
        if btn and not btn.hidden and not btn.kcBar then k = k + 1 end
    end
    if k == 0 then return 0 end
    local ostep = #other.keys > 1 and math.abs(other.to - other.from) / (#other.keys - 1) or 0
    local r, ro, d = ring.radius, other.radius, self.BTN / 2 + 12 -- (a full button and a small one, just apart)
    local c = (r * r + ro * ro - d * d) / (2 * r * ro)
    local clear = math.deg(math.acos(math.max(-1, math.min(1, c))))
    return 2 * ((k - 1) * ostep / 2 + clear)
end

-- A ring's spacing (degrees between slots), radius and middle angle, for n
-- slots on it. A ring whose slots are fixed spaces them as if all were
-- there. One that's a zone (ring.count: how many it usually holds, v23)
-- never moves further out. Up to its usual number it keeps its usual
-- spacing; more sit closer together along its arc, the arc reaching a
-- little further round (to ring.widest) before they'd touch, then closer
-- still. loop: nothing is below the line, so it may go round the kit: it
-- keeps its usual spacing, gathered opposite the line, and only reaches
-- further round once that runs out of room, as far as the buttons it has to
-- avoid, or, when there are too many for that, the whole way (round: true),
-- with those buttons moved outside it.
function Kit:RingGeo(ring, n, loop)
    local mid = (ring.from + ring.to) / 2
    local full = #ring.keys
    if not ring.count then
        return full > 1 and (ring.to - ring.from) / (full - 1) or 0, ring.radius, mid
    end
    n = n or full
    local span = math.abs(ring.to - ring.from)
    local sign = ring.to < ring.from and -1 or 1
    local cap = loop and 360 or math.max(span, ring.widest or span)
    local gap = self:RingGap(ring)
    if gap > 0 then cap = math.max(span, math.min(cap, 360 - gap)) end
    local step, round = 0, false
    if n > 1 then
        local touch = math.deg(2 * math.asin(math.min(1, (self.BTN + 1) / (2 * ring.radius))))
        if loop then
            -- (too many to fit beside the buttons it avoids: the whole circle,
            -- and those buttons move outside it, see LayoutOneRing)
            if gap > 0 and (n - 1) * touch > cap then cap, round = 360, true end
            -- Still gathered on the far side from the line at the usual
            -- spacing (v34); it only spreads further round when that runs
            -- out of room, and goes evenly round once it fills the circle.
            local usual = ring.count > 1 and span / (ring.count - 1) or touch
            step = math.min(360 / n, math.max(usual, touch), cap / (n - 1))
        elseif n <= ring.count then
            step = ring.count > 1 and span / (ring.count - 1) or 0
        else
            step = math.max(span, math.min(cap, (n - 1) * touch)) / (n - 1)
        end
    end
    return sign * step, ring.radius, mid, round
end

-- Every slot's home spot: its place in a ring (cfg.ring) or its pos, turned
-- the way the layout faces. True if any moved.
function Kit:LayoutHomes()
    local base = {}
    local rings = self.cfg.ring
    if rings then
        if rings.keys then rings = { rings } end
        self.ringPush = nil
        for i, ring in ipairs(rings) do self:LayoutOneRing(ring, base, i) end
    end
    local moved = false
    local sp = self.db.spread or 1 -- (Distance from center)
    for _, btn in pairs(self.slots) do
        local b = base[btn] or btn.slot.pos
        local x, y = self:Face(b[1] * sp, b[2] * sp)
        if self.trial then
            self.trial.home[btn] = { x, y } -- (the real home spots stay as they are)
        elseif btn.homeX ~= x or btn.homeY ~= y then
            btn.homeX, btn.homeY = x, y
            moved = true
        end
    end
    return moved
end

-- The divider across the kit, turned with the layout.
function Kit:FaceDivider()
    local dv, d = self.divider, self.cfg.divider
    if not dv or dv.edged then return end
    local sp = self.db.spread or 1
    local x, y = self:Face(0, d.y * sp)
    local w = (d.width or 200) * sp
    local side = self:Sideways()
    dv:ClearAllPoints()
    dv:SetPoint("CENTER", self.kit, "CENTER", x, y)
    dv:SetSize(side and 16 or w, side and w or 16)
    dv.tex:SetSize(w, 16)
    dv.tex:SetRotation(side and math.pi / 2 or 0)
end

-- Whether a slot is out in the layout being placed: the trial one (see
-- TrialLayout), or as it is on screen.
function Kit:WouldShow(btn)
    if self.trial then return self.trial.vis[btn] and true or false end
    return btn:IsShown() and not btn.closing and true or false
end

function Kit:PlaceSlots()
    self:PlaceKitSlots()
    -- (the buttons on bars, last: the kit's own layout has left them alone)
    if not self.trial then self:PlaceBars(true) end
end

function Kit:PlaceKitSlots()
    local ringMoved = self:LayoutHomes()
    -- In a Kit Dock box and closed: what shows (reminders, pinned slots)
    -- goes in one row along the box with the other boxed kits' (Kit Dock
    -- places them), in the order the edge layout would put them.
    if self.parked and not self.open and self.edgeSide and self.Dock and self.Dock.BoxNotices and not self.trial then
        self.collect = {}
        local ok, err = pcall(self.PlaceEdge, self)
        local list = self.collect
        self.collect = nil
        -- The kit's own extras it places itself (timers and such), and any
        -- frame it names for the box (cfg.boxFrames), showing: in the row too.
        local more = {}
        for _, f in ipairs(self:Extras()) do more[#more + 1] = f end
        if self.cfg.boxFrames then
            for _, f in ipairs(self.cfg.boxFrames(self) or {}) do more[#more + 1] = f end
        end
        for _, f in ipairs(more) do
            local seen = false
            for _, g in ipairs(list) do if g == f then seen = true break end end
            if not seen and f:IsShown() then list[#list + 1] = f end
        end
        if not ok then
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
        self.Dock.BoxNotices(self.key, list)
        return
    end
    if self.edgeSide and self.Dock then return self:PlaceEdge() end
    if self.trial and not self.compactAngle then
        for btn, h in pairs(self.trial.home) do self:PlaceAt(btn, h[1], h[2]) end
        return
    end
    if not self.trial then
        self.liveDiv = false
        self:UnEdgeDivider()
        self:FaceDivider()
        for _, btn in pairs(self.slots) do self:PlaceSub(btn) end
    end
    local angle, span = self.compactAngle, self.compactSpan
    if not angle then
        -- Slots already out glide to new home spots (the ring closing up
        -- round a slot that went away, or opening back out).
        local from
        if ringMoved and self.Dock and self.Dock.Glide then
            from = {}
            for _, btn in pairs(self.slots) do
                if btn:IsShown() and not btn.closing and not sliding[btn] then
                    local x, y = btn:GetCenter()
                    if x then from[btn] = { x, y, btn:GetEffectiveScale() } end
                end
            end
        end
        for _, btn in pairs(self.slots) do self:PlaceAt(btn, btn.homeX, btn.homeY) end
        if self.cfg.PlaceExtras then self.cfg.PlaceExtras(self) end
        if from then
            for f, b in pairs(from) do self.Dock.Glide(f, b[1], b[2], b[3]) end
        end
        return
    end
    -- Shrunk on the dock: whatever's out fans round the button in its slice,
    -- in rings of 4, by tier (if the kit gives them), then pinned slots
    -- first, then the rest, each in slot order. Opened there in combat, that's
    -- every slot (the trial layout works it out ahead of time).
    -- Small rim slots keep a place on the button's rim, on the side the
    -- fan opens toward (away from the pin); the fan starts a little further
    -- out so nothing lands on them.
    local rimOut = self:PlaceRim(angle)
    -- (a kit's extras don't change between open and closed in the fan, so a
    -- trial leaves them alone)
    if self.cfg.PlaceExtras and not self.trial then self.cfg.PlaceExtras(self, angle) end
    local shown = {}
    for _, btn in pairs(self.slots) do
        if self:WouldShow(btn) and not btn.slot.rim and not btn.kcBar then shown[#shown + 1] = btn end
    end
    table.sort(shown, function(a, b)
        local ta, tb = a.slot.tier or 0, b.slot.tier or 0 -- (slot.tier: nearest ring first)
        if ta ~= tb then return ta < tb end
        local pa, pb = self.cdb.pinned[a.slot.key] and 1 or 0, self.cdb.pinned[b.slot.key] and 1 or 0
        if pa ~= pb then return pa > pb end
        return (a.order or 0) < (b.order or 0)
    end)
    local BTN, PER_RING = self.BTN, 4
    local half = self:KitHalfUnits() + (rimOut and 12 or 0)
    local r1 = math.max(half + (BTN / 2 + 4), (BTN + 4) * (PER_RING - 1) / math.rad(span or 115))
    local i = 0
    for ring = 1, math.ceil(#shown / PER_RING) do
        local n = math.min(PER_RING, #shown - (ring - 1) * PER_RING)
        local r = r1 + (ring - 1) * (BTN + 6)
        local step = math.deg((BTN + 4) / r)
        for j = 1, n do
            i = i + 1
            local a = math.rad(angle + (j - (n + 1) / 2) * step)
            self:PlaceAt(shown[i], r * math.cos(a), r * math.sin(a))
        end
    end
end

-- How far the open kit reaches from its centre (its slots and their corner
-- buttons), in UI units: left, right, top, bottom. The kit is kept at least
-- that far from the screen edges so everything fits.
function Kit:Reach()
    local s = self.db.scale
    local half = self.BTN / 2 + 4
    local ks = (self.kit:GetWidth() / 2) * s * (self.db.kitSize or 1) + 4
    local l, r, t, b = ks, ks, ks, ks
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        if not (btn and (btn.hidden or btn.kcBar)) then -- (a slot that isn't there, or is on a bar, doesn't need room)
        local sp = self.db.spread or 1
        local x, y = self:Face(slot.pos[1] * sp, slot.pos[2] * sp)
        local h = slot.small and 15 or half
        local extra = slot.sub and 8 or 0
        local below = slot.sub and slot.sub.below and 26 or 0
        local bx, by = self:Face(0, -below)
        l = math.max(l, (h - math.min(x, x + bx)) * s)
        r = math.max(r, (math.max(x, x + bx) + h + extra) * s)
        t = math.max(t, (math.max(y, y + by) + h) * s)
        b = math.max(b, (h + extra - math.min(y, y + by)) * s)
        end
    end
    return l, r, t, b
end

---------------------------------------------------------------------------
-- Refresh: what each slot holds and whether it shows (out of combat)
---------------------------------------------------------------------------

-- What each slot is and holds right now: the kit's BeforeRefresh, then every
-- slot's Update (and its assigned choice, and its corner button's Update).
function Kit:RunUpdates()
    local cfg = self.cfg
    if cfg.BeforeRefresh then cfg.BeforeRefresh(self) end
    for _, slot in ipairs(cfg.slots) do
        local btn = self.slots[slot.key]
        btn.hidden = nil
        if slot.Update then slot.Update(self, btn) end
        if slot.assign and not btn.hidden then self:ApplyAssigned(btn) end
        local sb = btn.sub
        if sb then
            sb.hidden = nil
            if sb.def.Update then sb.def.Update(self, sb) end
            sb:SetShown(not sb.hidden)
        end
    end
end

-- Whether a slot shows, with the kit open or closed as self.open says.
-- Also whether it's there at all, whether something pops it out, and
-- whether its reminder shows in the reminder panel (popped, not pinned,
-- ticked for the panel): then the slot itself only shows with the kit open,
-- and a copy of it in the panel stands in for it, open or closed. With
-- cfg.panelPinned a pinned slot's reminder goes in the panel too, and the
-- slot stays out by the kit as pinned slots do.
function Kit:SlotVisible(slot, btn)
    -- (v32) Hidden from the kit by its settings but still set up for its
    -- reminder (btn.panelWhenHidden): never shows by the kit, but its copy can
    -- still go in the reminder panel when it pops.
    local still = btn.hidden and btn.panelWhenHidden and true or false
    local pop = slot.Pop and (not btn.hidden or still) and slot.Pop(self, btn) or false
    local available = self.db.shown ~= false and (not btn.hidden or still)
    local pinned = self.cdb.pinned[slot.key] and true or false
    local bar = btn.kcBar and true or false -- (on a bar: always out, there)
    local out = (pinned or pop or bar) and true or false
    -- (pinned: it stays by the kit, reminder or not; on a bar: it stays on the bar)
    local panel = available and pop and (self.cfg.panelPinned or not pinned) and not bar and self:PanelAssigned(slot) or false
    local visible = available and not btn.hidden and (self.open or (out and (pinned or not panel) and not self.tucked and not self.quiet)) and true or false
    return visible, available, pop, panel and true or false
end

-- Can the kit button open and close this kit in combat? Shrunk on the pin
-- with other kits: yes, in place, every slot fanned out in its slice away
-- from the pin (nothing else moves; out of combat it takes the pin as
-- usual once combat ends). Parked in Kit Dock's box: no, its fan points off
-- the screen. Open on the pin (taking it, the others tucked): no, closing
-- would leave the others tucked.
function Kit:CanSecureToggle()
    if self.noSecureToggle then return false end
    local D = self.Dock
    -- In a Kit Dock box: no (it stays closed in combat, and it only steps out
    -- of the box out of combat).
    if self.parked or (D and D.IsParked and D.IsParked(self.key)) then return false end
    if self.compactAngle then
        return not (D and D.IsParked and D.IsParked(self.key)) and true or false
    end
    if D and D.IsDocked and D.IsDocked(self.key) and not self.edgeSide then return false end
    return true
end

-- Can the kit be dragged in combat? The same kits as open there, while it
-- isn't pinned in place.
function Kit:CanSecureMove()
    return not self.noSecureMove and not self.db.locked and (self:CanSecureToggle() or self:OnProtectedPin()) and true or false
end

-- On Kit Dock's pin with other kits, and the pin is a protected frame (Kit
-- Dock v19), so the grip can move the pin, and the whole dock with it.
function Kit:OnProtectedPin()
    local D = self.Dock
    if not (D and D.IsDocked and D.IsDocked(self.key)) then return false end
    if D.EdgeSide and D.EdgeSide(self.key) then return false end
    local pin = D.pin
    return pin and pin.IsProtected and pin:IsProtected() and D.SavePinAt and true or false
end

-- What the drag snippets need (out of combat): whether this kit may move,
-- and the button's scale against the holder's.
function Kit:PushMoveInfo()
    if InCombatLockdown() then return end
    local kit = self.kit
    kit:SetAttribute("kcmovable", self:CanSecureMove() and 1 or 0)
    local hs = self.holder:GetEffectiveScale()
    kit:SetAttribute("kcks", hs > 0 and kit:GetEffectiveScale() / hs or 1)
    kit:SetAttribute("kcmovestep", nil)
    local onPin = self.grip and self:OnProtectedPin()
    kit:SetAttribute("kconpin", onPin and 1 or 0)
    if onPin then
        local D = self.Dock
        local pin = D.pin
        SecureHandlerSetFrameRef(self.grip, "kcpin", pin)
        kit:SetAttribute("kcpinks", hs > 0 and pin:GetEffectiveScale() / hs or 1)
        -- Every kit on the pin (their buttons are secure: Kit Core v5 on),
        -- for the grip to move together (see GRIP_CLICK).
        local n = 0
        for key, api in pairs(D.kits or {}) do
            local b = api.kit
            if b and b.IsProtected and b:IsProtected() and D.IsDocked(key) and not (D.EdgeSide and D.EdgeSide(key)) then
                n = n + 1
                SecureHandlerSetFrameRef(self.grip, "kcdock" .. n, b)
                if b ~= kit then
                    local bs = b:GetEffectiveScale()
                    b:SetAttribute("kcks", hs > 0 and bs / hs or 1) -- (its own kit sets this too)
                end
            end
        end
        self.grip:SetAttribute("kcdockn", n)
    end
end

-- Where a frame's centre is, in UIParent units.
local function UICenter(f)
    local x, y = f:GetCenter()
    if not x then return nil end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * k, y * k
end

-- The faint copy of the kit button that follows the mouse while you drag it
-- in combat (not secure, so it can move). It starts where the button is,
-- and moves as the mouse has since you pressed.
function Kit:StartGhost()
    local g = self.ghost
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("TOOLTIP")
        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetAllPoints()
        local mask = g:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(g.icon)
        g.icon:AddMaskTexture(mask)
        g.ring = g:CreateTexture(nil, "OVERLAY")
        g.ring:SetAllPoints()
        g.ring:SetTexture(self.media .. "glow_ring")
        g.ring:SetBlendMode("ADD")
        g:Hide()
        g:SetScript("OnUpdate", function(f)
            -- (let go somewhere the release didn't reach: stop following)
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then f:Hide() return end
            local cx, cy = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            local dx, dy = cx / s - f.downX, cy / s - f.downY
            if not f.active then
                if dx * dx + dy * dy < 64 then return end -- (a click so far)
                f.active = true
                f:SetAlpha(0.55)
                GameTooltip:Hide()
            end
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", f.fromX + dx, f.fromY + dy)
        end)
        self.ghost = g
    end
    local kit = self.kit
    local x, y = UICenter(kit)
    if not x then return end
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    g.fromX, g.fromY = x, y
    g.downX, g.downY = cx / s, cy / s
    local size = kit:GetWidth() * kit:GetEffectiveScale() / s
    g:SetSize(size, size)
    g.icon:SetTexture(kit.icon:GetTexture())
    g.icon:SetTexCoord(kit.icon:GetTexCoord())
    g.active = false
    g:SetAlpha(0) -- (shows once the mouse has moved: until then it's a click)
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    g:Show()
end

function Kit:StopGhost()
    if self.ghost then self.ghost:Hide() end
end

-- In combat, the grip's press and click (after GRIP_CLICK): follow along.
function Kit:NoteCombatPress()
    self.combatPress = { UICenter(self.kit) }
    if self:CanSecureMove() then self:StartGhost() end
end

local MOVE_FAIL = {
    [""] = Loc["the press didn't reach the kit's secure code"],
    down = Loc["the game didn't give the kit the mouse position"],
    ["down-ok"] = Loc["the game didn't give the kit the mouse position on release"],
    ["up-pos"] = Loc["the game didn't give the kit the button's position"],
    ["up-rect"] = Loc["the game didn't let the kit move the button"],
}

function Kit:GripClicked(mouse, down)
    if mouse == "RightButton" then
        if IsShiftKeyDown() then self:OpenSettings() else self:OpenMenu() end
        return
    end
    if mouse ~= "LeftButton" or down then return end
    local dragged = self.ghost and self.ghost:IsShown() and self.ghost.active
    self:StopGhost()
    local press = self.combatPress
    self.combatPress = nil
    -- (where GRIP_CLICK put the button: the game's own answer lags behind)
    local kit = self.kit
    local step = kit:GetAttribute("kcmovestep")
    if step == "moved-pin" then
        -- The whole dock moved: the pin's new spot is saved for the dock, which
        -- lays everything out there after combat (see FinishCombatMove).
        local hs = self.holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
        self.Dock.SavePinAt((kit:GetAttribute("kcdropx") or 0) * hs, (kit:GetAttribute("kcdropy") or 0) * hs)
        self.pinMoved = true
    end
    local moved = step == "moved" or step == "moved-pin"
    local toggled = (kit:GetAttribute("kcisopen") == 1) ~= self.open
    if step == "moved" then
        local hs = self.holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y = (kit:GetAttribute("kcdropx") or 0) * hs, (kit:GetAttribute("kcdropy") or 0) * hs
        self.combatDrop = { x, y }
        -- Saved now, so anything that puts the kit at its saved spot as
        -- combat ends puts it here.
        self:SavePositionAt(x, y)
    end
    if toggled then self:CombatToggled() end -- (a click: GRIP_CLICK opened or closed it)
    if dragged and not moved and self:CanSecureMove() and not self.moveFailSaid then
        self.moveFailSaid = true
        local step = self.kit:GetAttribute("kcmovestep") or ""
        self:Print((Loc["Couldn't move the kit in combat: %s."]):format(MOVE_FAIL[step] or (Loc["stopped at %s"]):format(step)), true)
    elseif not (dragged or moved or toggled) then
        self:CombatToggled() -- (a click that didn't open it: says why)
    end
end

-- After combat: finish a drop made in combat as an ordinary drag would.
-- Called a frame after combat ends (see OnEvent), once the game has worked
-- out where everything is: read straight after a frame's anchor changes,
-- its position can come back as the screen's corner, and the kit and its
-- slots would glide in from there. The button is put back where it was
-- dropped first, in case the dock laid the kits out again as combat ended.
-- With Kit Dock, its own drag start and stop do the rest (snap to an edge
-- or another kit, save), with the button's StartMoving and
-- StopMovingOrSizing stood in for: there's no mouse drag to follow, and
-- those would re-anchor the button from wherever the game thinks it is.
function Kit:FinishCombatMove()
    if self.pinMoved and not InCombatLockdown() then
        self.pinMoved = nil
        if self.Dock and self.Dock.Layout then self.Dock.Layout() end -- (the pin to its saved spot, the kits round it)
    end
    local drop = self.combatDrop
    self.combatDrop = nil
    if not drop or InCombatLockdown() then return end
    local kit = self.kit
    local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = UICenter(kit)
    if not x or math.abs(x - drop[1]) > 1 or math.abs(y - drop[2]) > 1 then
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", drop[1] / k, drop[2] / k)
    end
    local D = self.Dock
    if D and D.DragStart and D.DragStop and D.kits and D.kits[self.key] then
        local function Still() end
        kit.StartMoving, kit.StopMovingOrSizing = Still, Still
        local ok, err = pcall(function()
            D.DragStart(self.key)
            D.DragStop(self.key)
        end)
        kit.StartMoving, kit.StopMovingOrSizing = nil, nil -- (the real ones again)
        if not ok then
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
    else
        self:SavePosition()
        self:KeepOnScreen()
    end
end

-- A layout (open or closed) for the combat switch: for every slot whether it
-- shows and where it goes, and for the divider whether it shows and where.
-- t = { vis = { [btn] = bool }, pos = { [btn] = { x, y } }, div = spec | false }
function Kit:StoreSnap(open, t)
    local snap = { vis = t.vis, pos = {}, div = t.div or false, rowOut = false }
    for btn, v in pairs(t.vis) do
        if v then
            local p = t.pos[btn]
            snap.pos[btn] = p and { p[1], p[2] } or { btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0 }
        end
    end
    local d = self.cfg.divider
    if open and d and not self.compactAngle then -- (no divider in a fan on the pin)
        for _, key in ipairs(d.below or {}) do
            local b = self.slots[key]
            if b and t.vis[b] and not b.kcBar then snap.rowOut = true end
        end
    end
    self.snap[open and true or false] = snap
end

-- The layout the kit isn't in right now, worked out without touching a frame:
-- the kit's own updates run again with kit.open flipped (kit.trial set), and
-- the placement code notes where each slot would go instead of moving it.
-- The refresh that follows runs the updates again for the real layout, so
-- nothing is left in the flipped state.
function Kit:TrialLayout()
    local real = self.open
    local t = { vis = {}, pos = {}, home = {}, div = false }
    self.trial, self.open = t, not real
    local ok, err = pcall(function()
        self:RunUpdates()
        for _, slot in ipairs(self.cfg.slots) do
            local btn = self.slots[slot.key]
            t.vis[btn] = (self:SlotVisible(slot, btn))
        end
        self:PlaceSlots()
    end)
    self.trial, self.open = nil, real
    if ok then
        self:StoreSnap(not real, t)
    else
        self.snap[not real] = nil
        if not self.trialFailed then -- (said once: it would come up on every refresh)
            self.trialFailed = true
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
    end
end

-- Hand every slot its two layouts as attributes, for the kit button's secure
-- snippet to use in combat (KIT_PRE). Out of combat only.
function Kit:PushSnapshot()
    local kit = self.kit
    local ready = self:CanSecureToggle() and self.snap[true] and self.snap[false] and true or false
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        btn:SetAttribute("kcbar", btn.kcBar and 1 or 0) -- (on a bar: the combat switch leaves it be)
        for _, which in ipairs({ { true, "o" }, { false, "c" } }) do
            local s = ready and self.snap[which[1]]
            local p = s and s.pos[btn]
            btn:SetAttribute("kc" .. which[2] .. "show", p and 1 or 0)
            btn:SetAttribute("kc" .. which[2] .. "x", p and p[1] or 0)
            btn:SetAttribute("kc" .. which[2] .. "y", p and p[2] or 0)
        end
    end
    kit:SetAttribute("kcisopen", self.open and 1 or 0)
    kit:SetAttribute("kcready", ready and 1 or 0)
    self:PushMoveInfo()
end

function Kit:Refresh(animate)
    if not self.built or self.trial then return end
    self.snap = self.snap or {} -- (a kit made by an older copy's NewKit, before this one loaded)
    if InCombatLockdown() then
        self.pending = true
        self:PaintAll()
        return
    end
    self.pending = false
    self:MarkBars()
    self:SizeZoneSlots() -- (a slot that moved zones while it couldn't change size)
    if self.opening then animate = "open" end -- a refresh from the dock's layout while this kit is opening
    local cfg, db, cdb = self.cfg, self.db, self.cdb

    local canToggle = self:CanSecureToggle()
    if canToggle then
        self:TrialLayout()
    else
        self.snap[true], self.snap[false] = nil, nil
    end
    self:RunUpdates()

    -- On an edge, slots already out (pinned or popped) move between the
    -- closed strip and their open columns: note where they are so they glide.
    local from
    if self.edgeSide and (animate == "open" or animate == "close") then
        from = {}
        local function Note(f)
            if f:IsShown() and not f.closing then
                local x, y = f:GetCenter()
                if x then from[f] = { x, y, f:GetEffectiveScale() } end
            end
        end
        for _, btn in pairs(self.slots) do Note(btn) end
        for _, f in ipairs(self:Extras()) do Note(f) end
    end

    local slides, total = {}, #cfg.slots
    local vis, inPanel = {}, {}
    for i, slot in ipairs(cfg.slots) do
        local btn = self.slots[slot.key]
        local visible, available, pop, panel = self:SlotVisible(slot, btn)
        vis[btn] = visible
        -- (its reminder in the panel: a copy there, see PlacePanelSlots)
        btn.inPanel = panel or nil
        if panel then inPanel[#inPanel + 1] = btn end
        if visible then
            CancelClose(self, btn)
            if not btn:IsShown() then
                btn:Show()
                if animate == "open" and not btn.kcBar then
                    slides[#slides + 1] = { btn, i } -- once it knows where it's going
                elseif animate == "untuck" and self.Dock and self.Dock.Fade and not Fighting() then
                    self.Dock.Fade(btn, false)
                end
            end
        elseif btn:IsShown() and not btn.closing then
            if btn.fly and btn.fly:IsShown() then btn.fly:Hide() end
            if btn.hidden or btn.kcBar or Fighting() then btn:Hide() else PlayClose(self, btn, i, total) end -- (see Fighting)
        end
        btn.wouldShow = available and not btn.hidden and not btn.kcBar and (cdb.pinned[slot.key] or (pop and not panel)) and true or false
    end

    -- The divider shows while the kit is open and its row below is out.
    local dv = self.divider
    if dv then
        local rowOut = false
        if self.open and not self.compactAngle then
            for _, key in ipairs(cfg.divider.below or {}) do
                local b = self.slots[key]
                if b and b:IsShown() and not b.closing and not b.kcBar then rowOut = true end
            end
        end
        -- (editing the layout: the line shows, so there's somewhere to drop a button below it)
        if self.editing and not self.compactAngle then rowOut = true end
        if rowOut and not dv:IsShown() then
            dv:Show()
            dv.fadeIn:Play()
        elseif not rowOut then
            dv:Hide()
        end
    end

    self:PlaceSlots()
    -- This kit's reminders in the panel (open or closed), in its own order.
    table.sort(inPanel, function(a, b) return (a.order or 0) < (b.order or 0) end)
    self.panelList = inPanel
    C.PanelLayout(self)
    self:LayoutFlyouts()
    for _, sl in ipairs(slides) do self:PlaySlide(sl[1], sl[2]) end
    if from and self.Dock and self.Dock.Glide then
        for f, b in pairs(from) do
            if f:IsShown() and not f.closing then self.Dock.Glide(f, b[1], b[2], b[3]) end
        end
    end
    -- This layout, for the combat switch, beside the other one worked out above.
    if canToggle then self:StoreSnap(self.open, { vis = vis, pos = {}, div = self.liveDiv }) end
    self:PushSnapshot()
    if self.radial then self:RadialRefresh() end
    self:PaintAll()
    if self.editing then self:PaintEdit() end
end

function Kit:SetOpen(want)
    if InCombatLockdown() then return end
    self.open = want and true or false
    self:CloseFlyouts()
    self:ArmOpenFade()
    local D = self.Dock
    if D and self.open then
        -- Docked: the kit glides onto the pin first, then its slots fan out.
        -- The dock's layout refreshes this kit on the way; self.opening makes
        -- that refresh slide the slots out rather than just show them.
        if D.IsDocked(self.key) then self.slideDelay = 0.18 end
        self.opening = true
        D.Opening(self.key)
        self.opening = nil
    end
    self:Refresh(self.open and "open" or "close")
    self.slideDelay = nil
    if D and not self.open then D.Closed(self.key) end
end

function Kit:Toggle()
    -- (a key binding or the minimap button: only a click on the kit button
    -- itself can run the secure snippet that opens it in combat)
    if InCombatLockdown() then
        self:Print(self:CanSecureToggle() and Loc["Click the kit button to open or close it in combat."]
            or Loc["That can only change out of combat."])
        return
    end
    self:SetOpen(not self.open)
end

-- The kit button was clicked in combat. Its secure snippet (KIT_PRE) has
-- already switched the slots, if it could, and said so in "kcisopen". This
-- catches up what a snippet can't reach: where the kit thinks everything is,
-- the divider, the fade, the paint, and the kit's own extras. Anything moved
-- is tidied by the refresh when combat ends.
function Kit:CombatToggled()
    local kit = self.kit
    self.snap = self.snap or {}
    local now = kit:GetAttribute("kcisopen") == 1
    local s = self.snap[now]
    if kit:GetAttribute("kcready") ~= 1 or now == self.open or not s then
        self:Print(Loc["That can only change out of combat."])
        return
    end
    self.open = now
    self:ArmOpenFade()
    self.combatToggled = true
    for btn, p in pairs(s.pos) do btn.placedX, btn.placedY = p[1], p[2] end
    local dv = self.divider
    if dv then
        dv:SetShown(s.rowOut and true or false)
        if s.rowOut then
            local sp = s.div
            dv:ClearAllPoints()
            if sp then
                dv:SetPoint("CENTER", kit, "CENTER", sp.x, sp.y)
                dv:SetSize(sp.w, sp.h)
                dv.tex:SetSize(sp.tw, 16)
                dv.tex:SetRotation(sp.rot)
                dv.edged = true
            else
                dv:SetPoint("CENTER", kit, "CENTER", self:Face(0, self.cfg.divider.y))
            end
        end
    end
    self:ApplyFade()
    self:PaintAll()
    if self.cfg.OnCombatToggle then self.cfg.OnCombatToggle(self, now) end
end

function Kit:TogglePin(key)
    local slot = self.slotByKey[key]
    if InCombatLockdown() or not slot or slot.noPin then return end
    if self.slots[key] and self.slots[key].kcBar then
        self:Print((Loc["%s is on a bar, so it's always shown. Edit the layout to move it."]):format(slot.label))
        return
    end
    self.cdb.pinned[key] = not self.cdb.pinned[key]
    self:Print((self.cdb.pinned[key] and Loc["%s: always shown."] or Loc["%s: hides when the kit closes."]):format(slot.label))
    self:Refresh(false)
    if self.Dock then self.Dock.Layout() end -- an edge strip grows or shrinks
    self:SettingsChanged()
end

---------------------------------------------------------------------------
-- Position, moving, tucking, showing
---------------------------------------------------------------------------

-- The kit's spot is saved as its centre, measured from the nearest part of
-- the screen (a corner, an edge's middle, or the middle) in UIParent units,
-- marked "ui". Anchor offsets are in a frame's own scale, so a spot saved in
-- the kit's own units moved whenever its size changed: the kit slid toward
-- or away from its anchor instead of growing and shrinking where it stands.
-- Spots saved before (no "ui" mark) are in the kit's own units; PlaceFree
-- puts those back as they were and saves them again the new way.
function Kit:SavePosition()
    local kit = self.kit
    local x, y = kit:GetCenter()
    if not x then return end
    local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
    self:SavePositionAt(x * k, y * k)
end

-- The same, for a centre given in UIParent units.
function Kit:SavePositionAt(x, y)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local h = x < W / 3 and "LEFT" or x > W * 2 / 3 and "RIGHT" or ""
    local v = y < H / 3 and "BOTTOM" or y > H * 2 / 3 and "TOP" or ""
    local rel = (v .. h ~= "") and (v .. h) or "CENTER"
    local ax = h == "LEFT" and 0 or h == "RIGHT" and W or W / 2
    local ay = v == "BOTTOM" and 0 or v == "TOP" and H or H / 2
    self.db.point = { "CENTER", rel, x - ax, y - ay, "ui" }
end

-- Pinned slots stay out while the kit is closed, anchored to its button, so
-- when the button moves in one go they'd jump while the button glides.
-- BeginMove notes where each showing slot is; EndMove, after the move,
-- slides each one from there in step with the button. Brackets can nest.
function Kit:BeginMove()
    self.moveDepth = (self.moveDepth or 0) + 1
    if self.moveDepth > 1 then return end
    self.slotSnap = {}
    local function Note(f)
        if f:IsShown() then
            local x, y = f:GetCenter()
            if x then self.slotSnap[f] = { x, y, f:GetEffectiveScale() } end
        end
    end
    for _, btn in pairs(self.slots) do Note(btn) end
    for _, f in ipairs(self:Extras()) do Note(f) end
end

function Kit:EndMove()
    self.moveDepth = math.max(0, (self.moveDepth or 1) - 1)
    if self.moveDepth > 0 then return end
    local snap = self.slotSnap or {}
    if self.Dock and self.Dock.Glide then
        for f, s in pairs(snap) do
            if f:IsShown() and not sliding[f] then
                self.Dock.Glide(f, s[1], s[2], s[3])
            end
        end
    end
    self.slotSnap = nil
end

-- Slide a free-standing kit in from the edge if its slots wouldn't fit.
function Kit:KeepOnScreen()
    if InCombatLockdown() then return end
    local kit = self.kit
    local l, r, t, b = self:Reach()
    local x, y = kit:GetCenter()
    if not x then return end
    local bx, by, bs = x, y, kit:GetEffectiveScale()
    local k = bs / UIParent:GetEffectiveScale()
    x, y = x * k, y * k
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local nx = math.min(math.max(x, l), math.max(l, W - r))
    local ny = math.min(math.max(y, b), math.max(b, H - t))
    if math.abs(nx - x) > 0.5 or math.abs(ny - y) > 0.5 then
        self:BeginMove()
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", nx / k, ny / k)
        self:SavePosition()
        if self.Dock and self.Dock.Glide then self.Dock.Glide(kit, bx, by, bs) end
        self:EndMove()
    end
end

-- This kit's own saved spot (when the dock isn't placing it).
function Kit:PlaceFree()
    local p = self.db.point
    local kit = self.kit
    kit:ClearAllPoints()
    if p[5] == "ui" then
        local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
        kit:SetPoint(p[1], UIParent, p[2], p[3] / k, p[4] / k)
    else
        kit:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        self:SavePosition()
    end
    self:KeepOnScreen()
end

-- Whether the mouse is over a piece of this kit away from its button: a
-- pinned slot, a reminder beside it, its small buttons (anything under the
-- kit's holder). Kit Dock keeps a tucked kit tucked over these (v27).
-- Buttons on bars or in the reminder panel don't count: they sit away from
-- the kit.
local function MouseFoci()
    if GetMouseFoci then
        local t = GetMouseFoci()
        return t and t[1]
    end
    return GetMouseFocus and GetMouseFocus()
end
function Kit:MouseOverParts()
    local f = MouseFoci()
    local holder = self.holder
    if not f or not holder or f == holder then return false end
    local n = 0
    while f and n < 12 do
        if f.kcBar or f.inPanel then return false end
        local up = f.GetParent and f:GetParent()
        if up == holder then return true end
        f, n = up, n + 1
    end
    return false
end

-- Hide (or bring back) the kit and its pinned slots while another docked
-- kit is open on the pin. Out of combat only (the dock makes sure).
function Kit:Tuck(on)
    on = on and true or false
    if self.tucked == on then return end
    self.tucked = on
    if InCombatLockdown() then return end
    local kit = self.kit
    local want = not on and self.db.shown ~= false
    if self.Dock and self.Dock.Fade and kit:IsShown() ~= want and not Fighting() then
        if want then
            kit:Show()
            self.Dock.Fade(kit, false)
        else
            self.Dock.Fade(kit, true, function()
                if self.tucked and not InCombatLockdown() then kit:Hide() end
            end)
        end
    else
        kit:SetShown(want)
    end
    self:Refresh(not on and "untuck" or false)
end

-- Parked in a Kit Dock box (a small button in a row): its pinned and popped
-- slots show just inside the box, laid out as on that edge. Out of combat
-- (the dock makes sure).
function Kit:Park(on)
    on = on and true or false
    if self.parked == on then return end
    self.parked = on
    self:ApplyCombatHide()
    self:Refresh(false)
end

-- Show or hide the whole kit (settings, the shared minimap menu, slash).
function Kit:SetShownKit(show)
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
    self.db.shown = show and true or false
    if not show and self.open then self:SetOpen(false) end
    self.kit:SetShown(show and not self.tucked)
    self:Refresh(false)
    if self.Dock then self.Dock.Layout() end
    self:SettingsChanged()
end

-- A docked kit (on the pin or a screen edge) is anchored by offsets in its
-- own scale, so resizing it before the dock places it would fling it away,
-- and the dock would then glide it back from there. The dock resizes it
-- itself (BaseScale) as it lays it out, from where it really stood. Slots
-- are resized inside one BeginMove / EndMove, so they glide to their new
-- spots with the button instead of snapping.
-- The slots' buttons at the Button size setting: each shrinks round its own
-- middle, so nothing moves (the spacing stays as the layout made it). Out of
-- combat only (the buttons are secure).
function Kit:ApplyButtonSize()
    if InCombatLockdown() then return end
    local bs = self.db.buttonSize or 1
    local function Size(b, base)
        local w = base * bs
        if math.abs(b:GetWidth() - w) < 0.01 then return end
        b:SetSize(w, w)
        if b.glow then b.glow:SetSize(w * (b.glowMul or 1.6), w * (b.glowMul or 1.6)) end
        if b.roundParts and b.roundParts.hl then b.roundParts.hl:SetSize(w * 1.35, w * 1.35) end
    end
    for _, btn in pairs(self.slots) do
        Size(btn, btn.isSmall and 22 or self.BTN)
        if btn.sub then
            Size(btn.sub, 22)
            self:PlaceSub(btn)
        end
    end
end

function Kit:ApplyPosition()
    if InCombatLockdown() then self.pending = true return end
    self:ApplyButtonSize()
    local db = self.db
    local scale = db.scale * (db.kitSize or 1)
    self:BeginMove()
    for _, btn in pairs(self.slots) do btn:SetScale(db.scale) end
    for _, fly in pairs(self.flyouts) do fly:SetScale(db.scale) end
    if self.divider then self.divider:SetScale(db.scale) end
    for _, f in ipairs(self:Extras()) do f:SetScale(db.scale) end
    if self.Dock and self.Dock.IsDocked(self.key) then
        -- (the dock glides the kit from its old size, so its scale is short
        -- of the new one until the glide ends: never set it here)
        self.Dock.Layout()
    else
        self.kit:SetScale(scale)
        self:PlaceFree()
    end
    self:SetKitArt()
    self:ApplyShapes()
    self:PlaceBars(false) -- (the bars' buttons, at the new size)
    if self.editing then self:PaintEdit() end
    self:EndMove()
    if C.PanelLayout then C.PanelLayout() end -- (the slots' size in the reminder panel)
end

function Kit:SettingsChanged()
    if self.OnSettingsChanged then self:OnSettingsChanged() end
end

---------------------------------------------------------------------------
-- ForeverImmersion (and any addon reading ForeverUI.elements)
---------------------------------------------------------------------------
-- ForeverImmersion fades frames it finds by global name, and shows one again
-- while the mouse is over its rectangle. The holder covers the whole screen,
-- so it can't be that frame: the mouse would always be "over" it. Instead
-- each kit has <prefix>Area, an empty frame that follows the bounds of what
-- the kit is showing. Alpha set on it is passed on to the holder, so the
-- whole kit (button, slots, flyouts, the kit's own frames) fades together.
-- Kit Core never sets the holder's alpha itself, so nothing fights over it.

-- Situations a kit shows in until the player changes it in ForeverImmersion.
local FUI_VISIBLE = { combat = true, target = true, resting = true, idle = true }

function Kit:UpdateArea()
    local area, holder = self.area, self.holder
    if not (area and holder) then return end
    local hs = holder:GetEffectiveScale()
    local W, H = holder:GetWidth(), holder:GetHeight()
    local l, b, r, t
    for _, f in ipairs({ holder:GetChildren() }) do
        if f ~= area and f:IsVisible() and not f.atPanel and not f.kcBar then -- (the reminder panel and the bars are elsewhere)
            local fl, fb, fw, fh = f:GetRect()
            if fl and fw and fw > 0 and fh > 0 then
                local sc = f:GetEffectiveScale() / hs
                fl, fb, fw, fh = fl * sc, fb * sc, fw * sc, fh * sc
                -- skip anything screen-sized (it would swallow the hover test)
                if fw < W * 0.6 and fh < H * 0.6 then
                    l = l and math.min(l, fl) or fl
                    b = b and math.min(b, fb) or fb
                    r = r and math.max(r, fl + fw) or fl + fw
                    t = t and math.max(t, fb + fh) or fb + fh
                end
            end
        end
    end
    if not l then area:Hide() return end
    area:ClearAllPoints()
    area:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", l, b)
    area:SetSize(r - l, t - b)
    area:Show()
end

function Kit:BuildArea()
    local holder = self.holder
    local area = CreateFrame("Frame", self.prefix .. "Area", holder)
    area:EnableMouse(false)
    area:SetSize(1, 1)
    self.area = area
    hooksecurefunc(area, "SetAlpha", function(_, a) holder:SetAlpha(a) end)
    local ticker = CreateFrame("Frame", nil, holder)
    ticker:SetScript("OnUpdate", function(f, elapsed)
        f.acc = (f.acc or 0) + elapsed
        if f.acc < 0.25 then return end
        f.acc = 0
        self:UpdateArea()
    end)
    self:UpdateArea()
end

function Kit:RegisterForeverUI()
    local UI = _G.ForeverUI
    if UI == nil then UI = {} _G.ForeverUI = UI end
    if type(UI) ~= "table" then return end
    if type(UI.elements) ~= "table" then UI.elements = {} end
    local key = "kit:" .. self.key
    for _, e in ipairs(UI.elements) do
        if type(e) == "table" and e.key == key then return end
    end
    UI.elements[#UI.elements + 1] = {
        key = key, label = self.name, frames = { self.prefix .. "Area" }, visible = FUI_VISIBLE,
    }
    UI.revision = (tonumber(UI.revision) or 0) + 1
end

---------------------------------------------------------------------------
-- Kit Dock
---------------------------------------------------------------------------

function Kit:RegisterDock()
    local D = self.Dock
    if not D then return end
    D.Register(self.key, {
        kit = self.kit,
        name = self.name,
        edgesOnly = self.cfg.edgesOnly,
        NoTuck = function() return self.db.edgeTuck == false end,
        OverParts = function() return self:MouseOverParts() end,
        IsOpen = function() return self.open and not self:QkbInPlace() end,
        Close = function() self:SetOpen(false) end,
        Tuck = function(on) self:Tuck(on) end,
        PlaceFree = function() self:PlaceFree() end,
        SaveFree = function() self:SavePosition() end,
        BaseScale = function() return self.db.scale * (self.db.kitSize or 1) end,
        Reach = function() return self:Reach() end,
        IsHidden = function() return self.db.shown == false end,
        SetHidden = function(hide) self:SetShownKit(not hide) end,
        OpenSettings = function() self:OpenSettings() end,
        ApplyMinimap = function() self:ApplyMinimap() end,
        BeginMove = function() self:BeginMove() end,
        EndMove = function() self:EndMove() end,
        SettingsChanged = function() self:SettingsChanged() end,
        HidesInCombat = function() return self:HidesInCombat() end,
        UiScale = function() return self.db.scale end,
        Park = function(on) self:Park(on) end,
        Refresh = function() if not InCombatLockdown() then self:Refresh(false) end end,
        -- In a Kit Dock box while another kit from it is open: pinned slots
        -- (and the kit's reminders, which the kit's own code hides on
        -- kit.quiet) slide away, and come back after.
        Quiet = function(on)
            self.quiet = on and true or nil
            if not InCombatLockdown() then self:Refresh(not on and "untuck" or false) end
        end,
        Compact = function(on, angle, span)
            self.compactAngle, self.compactSpan = on and angle or nil, span
            self:Refresh(false)
        end,
        Edge = function(side)
            self.edgeSide = side
            self:Refresh(false)
        end,
        EdgeExtent = function(side, asOpen) return self:EdgeExtent(side, asOpen) end,
    })
end

---------------------------------------------------------------------------
-- Minimap button: left-click settings, right-click open / close, drag to
-- slide it round the minimap. Steps aside for Kit Dock's shared button.
--
-- From v19 it's a LibDataBroker launcher shown by LibDBIcon (both shipped in
-- Libs/KitCore/Libs, loaded by the kit's .toc), named after the kit's prefix.
-- So square minimaps, minimap reskins and button-bag addons (Leatrix Plus,
-- MinimapButtonButton, ElvUI ...) place and collect it like any other
-- addon's button. Its spot is kept in db.minimapIcon (LibDBIcon's minimapPos
-- and hide); before v19 it was db.minimapAngle, which carries over once.
---------------------------------------------------------------------------

local function MinimapLibs()
    if not LibStub then return end
    return LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
end

-- Kit art has its own rim, so LibDBIcon's border and backing go and the art
-- is drawn 27 across inside the 31 button, as before v19, with no zoom on
-- press. A button-bag addon may restyle it again; that's its call.
-- (Kit Dock's shared button does the same.)
function U.StyleMinimapArt(name, art, glow)
    local _, dbi = MinimapLibs()
    local b = dbi and dbi:GetMinimapButton(name)
    if not b then return end
    if dbi.RemoveButtonBorder then dbi:RemoveButtonBorder(name) elseif b.border then b.border:Hide() end
    if dbi.RemoveButtonBackground then dbi:RemoveButtonBackground(name) elseif b.background then b.background:Hide() end
    local icon = b.icon
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.UpdateCoord = function(t) t:SetTexCoord(0, 1, 0, 1) end
    icon:UpdateCoord()
    icon:SetTexture(art, nil, nil, "LINEAR")
    if glow then
        b:SetHighlightTexture(glow)
        local hl = b:GetHighlightTexture()
        if hl then
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.5)
            hl:ClearAllPoints()
            hl:SetPoint("TOPLEFT", 2, -2)
            hl:SetPoint("BOTTOMRIGHT", -2, 2)
        end
    end
end

-- (Kept for kits that call it: LibDBIcon does the placing now.)
function Kit:PlaceMinimap()
    local _, dbi = MinimapLibs()
    if dbi and self.minimap then dbi:Refresh(self.prefix) end
end

function Kit:ApplyMinimap()
    local _, dbi = MinimapLibs()
    if not (dbi and self.minimap) then return end
    local shared = self.Dock and self.Dock.SharedMinimap and self.Dock.SharedMinimap()
    local show = self.db.minimapButton and not shared and true or false
    self.db.minimapIcon.hide = not show -- (button bags read this too)
    if show then dbi:Show(self.prefix) else dbi:Hide(self.prefix) end
end

function Kit:SetupMinimap()
    if self.minimap or not Minimap then return end
    local ldb, dbi = MinimapLibs()
    if not (ldb and dbi) then return end -- libraries missing: no button; settings and slash still work
    local db, name = self.db, self.prefix
    if type(db.minimapIcon) ~= "table" then
        db.minimapIcon = { minimapPos = (db.minimapAngle or 200) % 360 } -- the spot from before v19
    end
    local art = self.cfg.minimapArt and Val(self.cfg.minimapArt, self)
    local obj = ldb:GetDataObjectByName(name) or ldb:NewDataObject(name, {
        type = "launcher",
        label = self.name,
        icon = art or Val(self.cfg.minimapIcon, self) or 134400,
    })
    obj.OnClick = function(_, mouse)
        if mouse == "RightButton" then self:Toggle() else self:OpenSettings() end
    end
    obj.OnTooltipShow = function(tt)
        tt:AddLine(self.name)
        tt:AddLine(Loc["Left-click: settings"], 1, 1, 1)
        tt:AddLine(Loc["Right-click: open / close the kit"], 1, 1, 1)
        tt:AddLine(Loc["Drag: move around the minimap"], 1, 1, 1)
    end
    if not dbi:IsRegistered(name) then dbi:Register(name, obj, db.minimapIcon) end
    self.minimap = dbi:GetMinimapButton(name)
    if art then U.StyleMinimapArt(name, art, self.media .. "glow_ring") end
    self:ApplyMinimap()
end

---------------------------------------------------------------------------
-- Settings panel (Esc > Options > AddOns > the kit), modern Settings API.
-- If this build's API differs, the kit still works through its slash command.
---------------------------------------------------------------------------

function Kit:OpenSettings()
    -- The kit's own window, for kits that have it; the game's options page
    -- otherwise (or if the window can't be made).
    if self.cfg.optionsWindow and self:OpenOptions() then return end
    if self.openSettings then
        self.openSettings()
    else
        self:Print((Loc["The settings panel isn't available on this build. %s help lists the slash commands."]):format(self.cfg.slash and self.cfg.slash[1] or ""), true)
    end
end

-- Every setting, in order, through a builder S with Header, Subheader,
-- Checkbox, Slider, Dropdown and Button (and, in the kit's own window, Note,
-- Choice, Grid and Table: v24). The game's options page (BuildSettings) and
-- the kit's own window (OpenOptions) both draw from it.
--
-- The window (v24) shows each setting's description as its tooltip, not
-- under it, so a description can say all it needs to without making the
-- page long. Keep the names short and plain: they're what you read.
--
-- A kit can put pages of its own in the "Kit" group, right after General
-- (cfg.FirstSettings), and one with cfg.buttonTable sets its buttons' show,
-- pin and reminder choices in one table there (S.Table) instead of on Kit
-- Core's "Pinned buttons" page and its own lists.
function Kit:SettingsList(S)
    local cfg, db, cdb = self.cfg, self.db, self.cdb
    local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
    local refresh = function() self:Refresh(false) end
    local window = S.window
    local listed = cfg.slots
    if cfg.menuOrder then
        listed = {}
        for _, key in ipairs(cfg.menuOrder) do listed[#listed + 1] = self.slotByKey[key] end
    end

    S.Group(Loc["Kit"])
    S.Header(Loc["General"])
    if S.Grid then S.Grid(2) end
    S.Checkbox(db, "shown", (Loc["Show %s"]):format(self.name),
        Loc["Turn off to hide the whole kit (its button and every slot) without uninstalling it."],
        true, function() self:SetShownKit(db.shown) end)
    S.Checkbox(db, "locked", Loc["Lock it in place"], Loc["Stop the kit from being dragged. Also in the kit's right-click menu."], false)
    if self.Dock then
        S.Checkbox(db, "edgeTuck", Loc["Tuck at screen edge"],
            Loc["On a screen edge on its own, the kit slides half off the screen until you mouse over it. Turn off to keep it fully on the screen. In a tuck box it still tucks with the box."],
            true, refresh)
    end
    S.Checkbox(db, "minimapButton", Loc["Minimap button"],
        Loc["Left-click for these settings, right-click to open the kit, drag to move it."], true,
        function() self:ApplyMinimap() end)
    S.Checkbox(db, "chatNotices", Loc["Chat messages"],
        Loc["Notices in chat when something changes (pinned in place, always shown, snoozed and the like). Slash commands still answer in chat."], true)
    if S.Grid then S.Grid(1) end
    if cfg.GeneralSettings then cfg.GeneralSettings(self, S) end
    S.Subheader(Loc["In combat"])
    if not self.cfg.alwaysHideInCombat then
        S.Checkbox(db, "hideInCombat", Loc["Hide the kit in combat"], Loc["Hide the kit while you're in combat."], false,
            function() self:ApplyCombatHide() end)
    end
    S.Slider(db, "flyoutHide", Loc["Drawers close after"],
        Loc["In combat a drawer can't close when you click elsewhere, so it closes by itself this long after the mouse leaves it and its slot."],
        0.5, 0.2, 2, 0.1, function(v) return ("%.1fs"):format(v) end)
    if cfg.CombatSettings then cfg.CombatSettings(self, S) end

    S.Subheader(Loc["Fading"])
    local rearm = function() self:ArmOpenFade() self:ApplyFade() end
    local function Fading() return (db.fadeIdle or db.fadeOpen) and true or false end
    if window then
        S.Choice(Loc["Fade the kit"],
            Loc["When closed: the closed kit and its pinned slots fade until you mouse over them. When left open: the open kit fades once the mouse has been off it a while (it stays open). Mouse over to bring it back."],
            {
                { "never", Loc["Never"] },
                { "idle", Loc["When closed"] },
                { "open", Loc["When left open"] },
                { "both", Loc["Both"] },
            },
            function()
                if db.fadeIdle and db.fadeOpen then return "both" end
                return (db.fadeIdle and "idle") or (db.fadeOpen and "open") or "never"
            end,
            function(v)
                db.fadeIdle = (v == "idle" or v == "both")
                db.fadeOpen = (v == "open" or v == "both")
                refresh()
                rearm()
            end)
    else
        S.Checkbox(db, "fadeIdle", Loc["Fade when idle"],
            Loc["With the kit closed, it and its pinned slots fade until you mouse over them."], false, refresh)
        S.Checkbox(db, "fadeOpen", Loc["Fade when left open"],
            Loc["With the kit open, it and its slots fade once the mouse has been off them for a while. They stay open, and come back when you mouse over them."],
            false, rearm)
    end
    if S.Only then S.Only(function() return db.fadeOpen and true or false end) end
    S.Slider(db, "fadeOpenAfter", Loc["Fade an open kit after"],
        Loc["How long the mouse has to be off the open kit before it fades."],
        5, 1, 30, 1, function(v) return ("%ds"):format(v) end, rearm)
    if S.Only then S.Only(Fading) end
    S.Slider(db, "fadeAmount", Loc["How faded"],
        Loc["How see-through the kit's slots get when it fades: 0% is gone until you mouse over. The kit button fades half as much, so you can still find it."],
        0.4, 0, 0.9, 0.05, function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end, function() self:ApplyFade() end)

    -- The kit's own pages, right after General (v24).
    if cfg.FirstSettings then cfg.FirstSettings(self, S) end

    S.Header(Loc["Look"])
    S.Subheader(Loc["Size"])
    S.Slider(db, "scale", Loc["Whole kit"], Loc["The whole kit: the center icon, the buttons round it and the space between them."], 1, 0.6, 1.6, 0.05, pct,
        function() self:ApplyPosition() end)
    S.Slider(db, "kitSize", Loc["Center icon"], Loc["Just the icon in the middle: the buttons round it stay where they are."],
        1, 0.5, 1, 0.05, pct, function() self:ApplyPosition() end)
    S.Slider(db, "buttonSize", Loc["Buttons"], Loc["Just the buttons round the center icon: each gets smaller in its place, so they spread out a little."],
        1, 0.6, 1, 0.05, pct, function() self:ApplyPosition() end)
    S.Slider(db, "spread", Loc["Spread"], Loc["How far the buttons sit from the center icon: lower brings them in close, higher spreads them out."],
        1, 0.8, 1.5, 0.05, pct, function() self:Refresh(false) self:ApplyPosition() end)
    S.Subheader(Loc["Layout"])
    S.Dropdown(db, "facing", Loc["Buttons open toward"],
        Loc["Which way the slots lay out round the kit while it's floating. On a screen edge they always face the middle of the screen."],
        "up", {
            { "up", Loc["Up"] },
            { "down", Loc["Down"] },
            { "left", Loc["Left"] },
            { "right", Loc["Right"] },
        }, function() self:SetFacing(db.facing) end)
    if window then
        S.Choice(Loc["Tooltips"], Loc["Where a slot's tooltip shows: beside the slot, or where the game normally puts tooltips."],
            { { "beside", Loc["Beside the slot"] }, { "default", Loc["Game's spot"] } },
            function() return db.tooltipDefault and "default" or "beside" end,
            function(v) db.tooltipDefault = (v == "default") end)
    else
        S.Checkbox(db, "tooltipDefault", Loc["Default tooltip position"],
            Loc["Show slot tooltips where the game normally shows tooltips, instead of beside the slot."], false)
    end
    if cfg.LookSettings then cfg.LookSettings(self, S) end

    if not (cfg.buttonTable and window) then
        S.Header(Loc["Pinned buttons"])
        if S.Grid then S.Grid(2) end
        for _, slot in ipairs(listed) do
            if not slot.noPin then
                S.Checkbox(cdb.pinned, slot.key, slot.label,
                    Loc["Keep it out when the kit is closed (this character only). You can also shift-right-click the slot."],
                    false, refresh, "pin_" .. slot.key)
            end
        end
        if S.Grid then S.Grid(1) end
        if cfg.PinSettings then cfg.PinSettings(self, S) end
        S.Button(Loc["Slot choices"], Loc["Reset"], Loc["Put every slot back to its starting choice, and every list back in its starting order."], function()
            self:ResetSlotChoices()
        end)
    end

    -- Bars (v23), for a kit that has them.
    if cfg.bars then
        S.Header(Loc["Bars"])
        S.Button(Loc["Edit layout"], Loc["Edit"], Loc["Opens the kit and lets you drag its buttons. The shaded areas show where a button can go on the kit: drop it there, between two buttons or at an end. Drop a button away from the kit and it floats there, always shown. Drop another on it to make a bar, or between two to put it there. Drop a button on the kit's icon to put it back. Drag a bar by its box to move it. This character only; out of combat. Also in the kit's right-click menu."],
            function() self:ToggleEdit() end)
        S.Slider(db, "barGap", Loc["Spacing"], Loc["Room between the buttons on a bar."],
            4, 0, 16, 1, function(v) return tostring(v) end, refresh)
        S.Button(Loc["Layout"], Loc["Reset to defaults"], Loc["Put every button back where it started: off the bars, and the kit's own buttons in their usual places and order."], function() self:ResetLayout() end)
    end

    -- The radial, for controllers (v39).
    if cfg.radial and type(db.radial) == "table" then
        local rc = db.radial
        local redo = function() if self.radial then self.radial.sig = nil end refresh() end
        S.Header(Loc["Controller"])
        S.Checkbox(rc, "on", Loc["Radial on a controller"],
            (Loc["Use %s from a controller as a ring round the middle of the screen: hold its binding, tilt a stick at a button, let go. Works in combat."]):format(self.name),
            true, redo, "radialOn")
        if S.Note then
            S.Note(Loc["While it's up: A uses, X opens a drawer or the row under the line (with the stick centred: the inner ring), Y does a button's alternate, B goes back or closes."])
        end
        local on = function() return rc.on ~= false end
        S.Subheader(Loc["Opening it"], on)
        S.Button(Loc["Gamepad bar"], Loc["Make macro"],
            Loc["Puts a macro on your cursor that brings the ring up: drop it on a gamepad bar slot. Hold its button, tilt the stick at a button and let go; or tap it and use A."],
            function() self:RadialMacro() end)
        S.Button(Loc["Key binding"], Loc["Open"],
            (Loc["Bind a button to bring the ring up: hold it, tilt, let go. Under %s in the key bindings."]):format(self.name),
            function() self:OpenKeyBindings() end)
        S.Subheader(Loc["Picking"], on)
        S.Dropdown(rc, "stick", Loc["Pick with"], Loc["The stick that points at a button while the ring is up."],
            "right", { { "right", Loc["Right stick"] }, { "left", Loc["Left stick"] } }, redo)
        S.Checkbox(rc, "camera", Loc["Hold the camera still"],
            Loc["While the ring is up, the stick you pick with doesn't turn the camera (or move you, for the left stick)."],
            true, nil, "radialCamera")
        S.Subheader(Loc["Ring"], on)
        S.Slider(rc, "scale", Loc["Ring size"], "", 1, 0.6, 1.6, 0.05, pct,
            function() if self.radial and self.radial.display:IsShown() then self:RadialDraw() end end)
        S.Checkbox(rc, "names", Loc["Button names"], Loc["Each button's name under it."], true, nil, "radialNames")
    end

    -- The reminder panel (v21): whether this kit uses it, and which of its
    -- reminders go there, are this kit's own; the panel's layout and spot are
    -- shared by every kit. Its own page: in the "Kit" group for a kit with a
    -- button table, otherwise right
    -- after the kit's "Reminders" (or at the end of the kit's own settings if
    -- it has none).
    local panelDone = false
    local function PanelSection()
        if panelDone then return end
        panelDone = true
        S.Header(Loc["Reminder panel"])
        local rp = db.reminderPanel
        local shared = function() C.SharePanel(rp) end
        S.Checkbox(rp, "on", (Loc["Put %s's reminders in the panel"]):format(self.name),
            (Loc["One panel for all your kits that you can put anywhere. With this on and %s closed, its reminders show there, full size, instead of beside the kit. They stay in the panel while the kit is open too (and in their places in the kit). Each kit has its own switch, so some kits' reminders can be in the panel and others by their kit."]):format(self.name)
                .. " " .. (cfg.panelPinned and Loc["A pinned button stays by its kit, and its reminder shows in the panel too."] or Loc["A pinned button always stays by its kit."]),
            false, shared, "panelOn")
        local panelOn = function() return rp.on and true or false end
        S.Subheader(Loc["The panel (every kit)"], panelOn)
        S.Button(Loc["Place the panel"], Loc["Move"], Loc["Shows a grid and the panel's box of buttons: drag it where you want it. It snaps to the grid, the middle of the screen and your kit buttons; hold Shift to place it freely."],
            function() C.TogglePanelUnlocked(self) end)
        S.Dropdown(rp, "layout", Loc["Layout"], Loc["Rows: buttons side by side, then a new row. Columns: one under another, then a new column."],
            "row", { { "row", Loc["Rows"] }, { "column", Loc["Columns"] } }, shared)
        if S.Only then S.Only(function() return rp.layout ~= "column" end) end
        S.Slider(rp, "perRow", Loc["Buttons per row"], Loc["How many across before a new row starts."],
            8, 1, 20, 1, function(v) return tostring(v) end, shared)
        if S.Only then S.Only(function() return rp.layout == "column" end) end
        S.Slider(rp, "perCol", Loc["Buttons per column"], Loc["How many down before a new column starts."],
            8, 1, 20, 1, function(v) return tostring(v) end, shared)
        S.Checkbox(rp, "middle", Loc["Grow from the middle"],
            Loc["The first button sits in the middle of the row (column), the next ones spread out evenly either side, and each new row (column) starts in the middle again. Off: they fill from the corner below."],
            true, shared, "panelMiddle")
        S.Dropdown(rp, "corner", Loc["Start from"], Loc["The corner the first button goes in (growing from the middle: the side new rows or columns are added toward). The panel grows away from it, and stays put there."],
            "TOPLEFT", { { "TOPLEFT", Loc["Top left"] }, { "TOPRIGHT", Loc["Top right"] }, { "BOTTOMLEFT", Loc["Bottom left"] }, { "BOTTOMRIGHT", Loc["Bottom right"] } }, shared)
        S.Slider(rp, "size", Loc["Button size"], Loc["The buttons in the panel, the same for every kit (100% is a full slot)."],
            1, 0.5, 1.5, 0.05, pct, shared)
        S.Slider(rp, "gap", Loc["Spacing"], Loc["Room between the buttons."],
            4, 0, 16, 1, function(v) return tostring(v) end, shared)
        S.Checkbox(rp, "snap", Loc["Snap when placing"], Loc["Line the panel up with the grid, the middle of the screen and your kit buttons as you drag it."], true, shared, "panelSnap")
        if S.Only then S.Only(function() return rp.snap ~= false end) end
        S.Slider(rp, "grid", Loc["Grid size"], Loc["How far apart the grid's lines are while placing it."],
            16, 8, 32, 8, function(v) return tostring(v) end, shared)
        local pops = {}
        for _, slot in ipairs(listed) do
            if not slot.noPanel and slot.Pop then pops[#pops + 1] = slot end
        end
        if #pops > 0 then
            S.Subheader(Loc["Reminders in the panel"], panelOn)
            if S.Grid then S.Grid(2) end
            for _, slot in ipairs(pops) do
                S.Checkbox(db.panelSlots, slot.key, slot.label,
                    Loc["When it pops out with the kit closed (missing or wanted), it shows in the panel."] .. " " .. (cfg.panelPinned and Loc["Pinned, it shows in the panel too, and stays by the kit."] or Loc["Pinned, it stays by the kit."]),
                    self:PanelDefault(slot), refresh, "panel_" .. slot.key)
            end
            if S.Grid then S.Grid(1) end
        end
    end
    if cfg.buttonTable and window then PanelSection() end

    -- (Key bindings: a link at the foot of the window's list, v24. The
    -- game's options page keeps its button.)
    if not window then
        S.Header(Loc["Key bindings"])
        S.Button(Loc["Key bindings"], Loc["Open"], Loc["Bind each slot, and opening the kit."], function() self:OpenKeyBindings() end)
    end

    -- The kit's own settings, under its name unless it opens with a header
    -- (and its own group in the window's list unless it names one).
    S.Group(self.name)
    S.Header(self.name)
    -- (the panel's section goes in when the section after "Reminders" starts)
    local afterReminders = false
    local KS = setmetatable({}, { __index = S })
    function KS.Header(text)
        if afterReminders then afterReminders = false PanelSection() end
        S.Header(text)
        if text == "Reminders" or text == Loc["Reminders"] then afterReminders = true end
    end
    function KS.Group(text)
        if afterReminders then afterReminders = false PanelSection() end
        S.Group(text)
    end
    if cfg.Settings then cfg.Settings(self, KS) end
    S.Group(self.name) -- (a kit with no "Reminders": at the end of its own group)
    PanelSection()
end

-- Every slot back to its starting choice, and every list in its starting order.
function Kit:ResetSlotChoices()
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
    wipe(self.cdb.picks)
    wipe(self.cdb.order)
    self:Refresh(false)
    self:Print(Loc["Slot choices reset."])
end

function Kit:OpenKeyBindings()
    if Settings and Settings.KEYBINDINGS_CATEGORY_ID then
        if self.optionsUI and self.optionsUI.frame then self.optionsUI.frame:Hide() end
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
    else
        self:Print((Loc["Open Esc > Options > Keybindings and look for %s."]):format(self.name))
    end
end

function Kit:BuildSettings()
    local cfg, db, cdb = self.cfg, self.db, self.cdb
    local registered = {}
    local VAR_BOOL = (Settings.VarType and Settings.VarType.Boolean) or "boolean"
    local VAR_NUM = (Settings.VarType and Settings.VarType.Number) or "number"
    local category, layout = Settings.RegisterVerticalLayoutCategory(self.name)
    local P = self.prefix

    local function OnChange(setting, fn)
        if not fn then return end
        if Settings.SetOnValueChangedCallback then
            Settings.SetOnValueChangedCallback(setting:GetVariable(), function() fn() end)
        elseif setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(function() fn() end)
        end
    end

    -- A header goes in only once something follows it, and a header straight
    -- after another replaces it (so a kit's section can open with its own).
    -- A sub-heading groups settings inside a section; in the game's list it's
    -- a header of its own, likewise only once something follows it.
    local S, pending, pendingSub = {}, nil, nil
    function S.Header(text) pending, pendingSub = text, nil end
    function S.Subheader(text) pendingSub = text end -- (its "when" is the window's only)
    function S.Group() end -- (the window's nav only)
    function S.Only() end -- (the window's only)
    -- (the window's only, v24: a line of words, a choice read and stored by
    -- functions, side-by-side checkboxes, and a kit's table of buttons;
    -- v30: a kit's own frame)
    function S.Note() end
    function S.Choice() end
    function S.Grid() end
    function S.Table() end
    function S.Custom() end
    function S.Colors() end -- (the window's only, v29: a row of colour squares)
    local function Flush()
        if CreateSettingsListSectionHeaderInitializer then
            if pending then layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(pending)) end
            if pendingSub then layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(pendingSub)) end
        end
        pending, pendingSub = nil, nil
    end
    function S.Checkbox(tbl, key, name, tooltip, default, fn, id)
        Flush()
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. (id or key), key, tbl, VAR_BOOL, name, default)
        Settings.CreateCheckbox(category, s, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    function S.Slider(tbl, key, name, tooltip, default, min, max, step, fmt, fn)
        Flush()
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. key, key, tbl, VAR_NUM, name, default)
        local opts = Settings.CreateSliderOptions(min, max, step)
        if MinimalSliderWithSteppersMixin and fmt then
            opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
        end
        Settings.CreateSlider(category, s, opts, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    -- list: { { value, label }, ... } (string values)
    function S.Dropdown(tbl, key, name, tooltip, default, list, fn)
        if not (Settings.CreateDropdown and Settings.CreateControlTextContainer) then return end
        Flush()
        local VAR_STR = (Settings.VarType and Settings.VarType.String) or "string"
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. key, key, tbl, VAR_STR, name, default)
        local function Options()
            local c = Settings.CreateControlTextContainer()
            for _, o in ipairs(list) do c:Add(o[1], o[2]) end
            return c:GetData()
        end
        Settings.CreateDropdown(category, s, Options, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    function S.Button(name, text, tooltip, fn)
        if CreateSettingsButtonInitializer then
            Flush()
            layout:AddInitializer(CreateSettingsButtonInitializer(name, text, fn, tooltip, true))
        end
    end
    self:SettingsList(S)

    Settings.RegisterAddOnCategory(category)
    self.openSettings = function() Settings.OpenToCategory(category:GetID()) end
    self.OnSettingsChanged = function()
        for _, r in ipairs(registered) do
            if r.setting.GetValue and r.setting:GetValue() ~= r.tbl[r.key] then
                pcall(r.setting.SetValue, r.setting, r.tbl[r.key])
            end
        end
    end
end

---------------------------------------------------------------------------
-- The kit's own settings window (cfg.optionsWindow = true): the same list
-- as the game's options page, drawn in the kits' panel look (a dark panel
-- with the gold tooltip edge, a gold title over a faint gold line), its
-- sections down the left and the chosen one's settings on the right, each
-- with its description under it. The game's options page only has a button
-- that opens it (v17).
---------------------------------------------------------------------------

local OPT = { w = 680, h = 620, nav = 172, head = 40, pad = 14, gap = 14 }
local GOLD = { 0.78, 0.64, 0.3 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local function OptPanel(kind, name, parent)
    local ok, f = pcall(CreateFrame, kind or "Frame", name, parent, "BackdropTemplate")
    if not ok or not f then f = CreateFrame(kind or "Frame", name, parent) end
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE8, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.04, 0.03, 0.05, 0.94)
        f:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.04, 0.03, 0.05, 0.94)
    end
    return f
end

-- A thin gold line round a frame (wells, boxes, the dropdown).
local function GoldEdge(f, a)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(1) else t:SetHeight(1) end
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], a or 0.6)
    end
end

local function Well(f, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0, 0, 0, a or 0.6)
    GoldEdge(f, 0.55)
end

---------------------------------------------------------------------------
-- The reminder panel (from v21)
--
-- One panel for every kit, which you can put anywhere. Each kit has its
-- own switch for it, so some kits' reminders can be there and others by
-- their kit. For a kit that uses it, each reminder ticked in its settings
-- shows in the panel instead of by the closed kit, as a full-size copy of
-- the slot (PanelTwin): it looks like the slot, glows and counts down with
-- it, and casts or uses what the slot does. The copy stays in the panel
-- while the kit is open too (the slot is in its place in the kit as well),
-- so the panel doesn't change as kits open and close, in combat or out.
-- A pinned slot never goes there: pinned means it stays by the kit, even
-- when it's also a reminder.
--
-- The panel is a grid of cells, all one size (the panel's Button size plus
-- Spacing), so everything in it lines up. Row layout: so many across
-- (Buttons per row), then a new row; Column layout: so many down, then a
-- new column. It fills from the corner you choose (Start from), and that
-- corner is where it's kept, so it grows away from it. Kits' slots follow
-- each other in the order the kits loaded, each kit's in its own order.
--
-- Moving it works like placing Shuklock's Scrolling Battle Text's scroll
-- areas: a grid over the screen (gold lines every grid step out from the
-- middle, the centre lines brighter), the panel shown as its full box of
-- cells, and a bar at the top with the grid size, Snap and Done. The box
-- snaps to the screen's centre lines and to the kit buttons' edges and
-- centres (a bright guide line shows what it lined up with), otherwise its
-- starting corner to the grid. Hold Shift to place it freely.
--
-- The panel is a secure frame (the copies, which are secure, hang from it),
-- so it's only moved and resized out of combat; the copies only come and go
-- out of combat too, like the kits' own reminders. Its settings are shared: Kit
-- Core has no saved variables of its own, so every kit keeps a copy
-- (db.reminderPanel) and the one changed last (stamp) wins at login.
---------------------------------------------------------------------------

local PANEL_FIELDS = { "layout", "x", "y", "perRow", "perCol", "corner", "middle", "size", "gap", "grid", "snap" }
local PANEL_BASE = 37      -- a full slot at 100%; every cell is this times the panel's Button size
local PANEL_PAD = 4        -- round the cells, inside the box
local PANEL_ALIGN = 10     -- how close (UI units) counts as lined up with something
local CORNERS = {
    TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 }, BOTTOMLEFT = { -1, -1 }, BOTTOMRIGHT = { 1, -1 },
}

-- The shared settings (the newest copy).
function C.PanelCfg()
    if C.pcfg then return C.pcfg end
    local best
    for _, kit in ipairs(C.kits or {}) do
        local p = kit.db and kit.db.reminderPanel
        if p and (not best or (p.stamp or 0) > (best.stamp or 0)) then best = p end
    end
    return best
end

-- Whether any kit uses the panel (each kit has its own switch, Kit:PanelOn).
function C.PanelOn()
    for _, kit in ipairs(C.kits or {}) do
        if kit:PanelOn() then return true end
    end
    return false
end

function Kit:PanelOn()
    local p = self.db and self.db.reminderPanel
    return p and p.on and true or false
end

-- The settings with anything missing or out of range made sensible.
local function PanelValues()
    local p = C.PanelCfg() or {}
    local corner = CORNERS[p.corner] and p.corner or "TOPLEFT"
    local size = math.min(1.5, math.max(0.5, tonumber(p.size) or 1))
    local gap = math.min(16, math.max(0, tonumber(p.gap) or 4))
    local per = p.layout == "column" and p.perCol or p.perRow
    per = math.min(20, math.max(1, math.floor(tonumber(per) or 8)))
    return p, corner, size, gap, per, p.layout == "column", p.middle ~= false
end

-- Every kit's copy made the same as the newest (at each kit's build).
function C.SyncPanel()
    C.pcfg = nil
    local best = C.PanelCfg()
    if not best then return end
    for _, kit in ipairs(C.kits or {}) do
        local p = kit.db and kit.db.reminderPanel
        if p and p ~= best then
            for _, f in ipairs(PANEL_FIELDS) do p[f] = best[f] end
            p.stamp = best.stamp
        end
    end
    C.pcfg = best
end

-- A kit's copy was just changed (src): it becomes the newest, every other
-- kit's copy follows it, and every kit lays itself out again.
function C.SharePanel(src)
    local top = 0
    for _, kit in ipairs(C.kits or {}) do
        local p = kit.db and kit.db.reminderPanel
        if p then top = math.max(top, p.stamp or 0) end
    end
    src.stamp = top + 1
    for _, kit in ipairs(C.kits or {}) do
        local p = kit.db and kit.db.reminderPanel
        if p and p ~= src then
            for _, f in ipairs(PANEL_FIELDS) do p[f] = src[f] end
            p.stamp = src.stamp
        end
    end
    C.pcfg = src
    if not C.PanelOn() and C.panelUnlocked then C.SetPanelUnlocked(false) end
    C.PlacePanel()
    for _, kit in ipairs(C.kits or {}) do
        if kit.built then
            kit:Refresh(false) -- (in combat: when it ends)
            kit:SettingsChanged()
            if kit.optionsUI and kit.optionsUI.frame:IsShown() then kit:PaintOptions() end
        end
    end
    if C.placeUI then C.placeUI.paint() end
    if C.editBar and C.editBar.paint and C.editKit then C.editBar.paint() end
end

local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s - UIParent:GetWidth() / 2, y / s - UIParent:GetHeight() / 2
end

local function Round(v, step) return math.floor(v / step + 0.5) * step end

---------------------------------------------------------------------------
-- The panel frame
---------------------------------------------------------------------------

-- Made the first time a kit asks (BuildKit).
function C.Panel()
    if C.panel then return C.panel end
    local ok, f = pcall(CreateFrame, "Frame", "KitCoreReminderPanel", UIParent, "SecureHandlerBaseTemplate")
    if not ok or not f then f = CreateFrame("Frame", "KitCoreReminderPanel", UIParent) end
    f:SetSize(40, 40)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(5) -- (under the slots it holds)
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f:SetPoint("TOPLEFT", UIParent, "CENTER", -100, -180)

    -- Only seen while it's being placed: a gold box (the cells it can fill)
    -- with its name over it.
    local edit = OptPanel("Frame", nil, f)
    edit:SetAllPoints()
    if edit.SetBackdropColor then edit:SetBackdropColor(0.78, 0.64, 0.3, 0.12) end
    edit.title = edit:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    edit.title:SetPoint("BOTTOM", edit, "TOP", 0, 3)
    edit.title:SetText(Loc["Kit reminders"])
    edit.size = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    edit.size:SetPoint("TOP", edit, "BOTTOM", 0, -3)
    edit.cells = {}
    edit:Hide()
    f.edit = edit

    -- Dragged by hand (not StartMoving), so it can snap as it goes: on the
    -- shared placing grid (v24), with every other piece being placed.
    f:SetScript("OnMouseDown", function(p, mouse)
        if mouse ~= "LeftButton" or InCombatLockdown() or not C.panelUnlocked then return end
        GameTooltip:Hide()
        C.Place.Begin("panel", p, function(x, y)
            local cfg, corner = PanelValues()
            local c = CORNERS[corner]
            cfg.x = math.floor(x + c[1] * p:GetWidth() / 2 + 0.5)
            cfg.y = math.floor(y + c[2] * p:GetHeight() / 2 + 0.5)
            C.PlacePanel()
        end)
    end)
    f:SetScript("OnMouseUp", function(_, mouse)
        if C.Place.Stop() then
            C.SharePanel(C.PanelCfg())
        elseif mouse == "RightButton" then
            C.SetPanelUnlocked(false)
        end
    end)
    f:SetScript("OnEnter", function(p)
        if not C.panelUnlocked then return end
        GameTooltip:SetOwner(p, "ANCHOR_TOP")
        GameTooltip:AddLine(Loc["Kit reminders"])
        GameTooltip:AddLine(Loc["Drag to move. Hold Shift to place it freely."], 1, 1, 1)
        GameTooltip:AddLine(Loc["Right-click when you're done."], 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Last, after the mouse scripts above: setting them turns the mouse back on,
    -- and the panel's box would block clicks to whatever is under it. It only
    -- takes the mouse while it's being placed (SetPanelUnlocked); the reminder
    -- buttons in it are their own frames and stay clickable.
    if not InCombatLockdown() then f:EnableMouse(false) end

    -- Combat starting while it's being placed: done placing (still allowed now).
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if C.panelUnlocked and not InCombatLockdown() then C.SetPanelUnlocked(false) end
        elseif C.panelPending then
            C.panelPending = nil
            C.PlacePanel()
            C.PanelLayout()
        end
    end)
    C.panel = f
    return f
end

-- Its saved spot: the starting corner, from the screen's centre.
function C.PlacePanel()
    local f = C.panel
    if not f then return end
    if InCombatLockdown() then C.panelPending = true return end
    local p, corner = PanelValues()
    local x, y = tonumber(p.x) or -100, tonumber(p.y) or -180
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint(corner, UIParent, "CENTER", x / k, y / k)
end

-- The box's centre from the screen's centre, from its corner and size.
function C.PanelCentre()
    local f = C.panel
    local p, corner = PanelValues()
    local c = CORNERS[corner]
    local x, y = tonumber(p.x) or -100, tonumber(p.y) or -180
    return x - c[1] * f:GetWidth() / 2, y - c[2] * f:GetHeight() / 2
end

---------------------------------------------------------------------------
-- Placing things (v24): one grid and one bar for every piece that can be
-- moved, as SSBT's Move.lua does it
--
-- Any kit can register a piece of its own (C.RegisterMover: a DoT stack, a
-- proc timer, the target bar...); the reminder panel is one too. While any
-- piece is being placed, the screen is shaded with gold grid lines every grid
-- step out from the middle (the middle lines brighter), and a small bar at
-- the top has the grid size, Snap and Done (Esc closes it too). Dragged, a
-- piece snaps to the screen's middle lines, to the other pieces' and the kit
-- buttons' edges and middles (a bright guide line shows what it lined up
-- with), or else its left and top edges to the grid. Shift places it freely.
--
-- "Move everything" (C.MoveAll: the foot of the settings window's list, or
-- "move" after the kit's slash command) puts every piece that's in use
-- into placing at once; Done ends them all. The grid size and Snap are the
-- reminder panel's (shared by every kit).
---------------------------------------------------------------------------

local movers, moverOrder = {}, {}
C.movers = movers
local placeUI, placeDrag

-- A piece that can be placed. m = {
--   label,                 its name
--   frame = fn() -> frame, what's dragged (nil before it's made)
--   test = fn(on),         shows it (a sample where it sits) to be placed, or stops
--   can = fn() -> bool,    whether it's in use, for Move everything
--   done = fn(),           Done or Esc: stop placing it (test(false) if not given)
--   strata,                its usual strata (back to it when placing ends)
-- }
function C.RegisterMover(key, m)
    if not movers[key] then moverOrder[#moverOrder + 1] = key end
    local old = movers[key]
    if old then m.placing = old.placing end
    movers[key] = m
end

-- Whether any piece is being placed now.
local function AnyPlacing()
    for _, k in ipairs(moverOrder) do if movers[k].placing then return true end end
    return false
end

local function PlaceCfg()
    local p = C.PanelCfg() or {}
    return tonumber(p.grid) or 16, p.snap ~= false, p
end

-- The cursor, in UI units from the middle of the screen.
local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s - UIParent:GetWidth() / 2, y / s - UIParent:GetHeight() / 2
end

local function Round(v, step) return math.floor(v / step + 0.5) * step end

-- A frame's middle and half-size, in UI units from the middle of the screen.
local function Box(f)
    local cx, cy = f:GetCenter()
    if not cx then return nil end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    return cx * k - ux, cy * k - uy, f:GetWidth() * k / 2, f:GetHeight() * k / 2
end

local function BuildGrid()
    local g = CreateFrame("Frame", "KitCoreGrid", UIParent)
    g:SetAllPoints()
    g:SetFrameStrata("HIGH")
    g:SetFrameLevel(1)
    g:EnableMouse(false)
    local shade = g:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.25)
    g.lines = {}
    g.guideV = g:CreateTexture(nil, "OVERLAY")
    g.guideV:SetWidth(2)
    g.guideV:SetColorTexture(1, 0.85, 0.45, 0.9)
    g.guideH = g:CreateTexture(nil, "OVERLAY")
    g.guideH:SetHeight(2)
    g.guideH:SetColorTexture(1, 0.85, 0.45, 0.9)
    g:SetScript("OnSizeChanged", function() if g:IsShown() then C.DrawGrid() end end)
    g:Hide()
    return g
end

function C.DrawGrid()
    local g = C.grid
    if not g then return end
    local step = PlaceCfg()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local n = 0
    local function Add(vertical, at)
        n = n + 1
        local t = g.lines[n]
        if not t then
            t = g:CreateTexture(nil, "ARTWORK")
            g.lines[n] = t
        end
        t:ClearAllPoints()
        t:Show()
        local centre = math.abs(at) < 0.5
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], centre and 0.45 or 0.1)
        if vertical then
            t:SetWidth(centre and 2 or 1)
            t:SetPoint("TOP", UIParent, "TOP", at, 0)
            t:SetPoint("BOTTOM", UIParent, "BOTTOM", at, 0)
        else
            t:SetHeight(centre and 2 or 1)
            t:SetPoint("LEFT", UIParent, "LEFT", 0, at)
            t:SetPoint("RIGHT", UIParent, "RIGHT", 0, at)
        end
    end
    for x = 0, w / 2, step do
        Add(true, x)
        if x > 0 then Add(true, -x) end
    end
    for y = 0, h / 2, step do
        Add(false, y)
        if y > 0 then Add(false, -y) end
    end
    for i = n + 1, #g.lines do g.lines[i]:Hide() end
end

function C.Guide(vx, hy)
    local g = C.grid
    if not g then return end
    g.guideV:ClearAllPoints()
    g.guideH:ClearAllPoints()
    if vx then
        g.guideV:SetPoint("TOP", UIParent, "TOP", vx, 0)
        g.guideV:SetPoint("BOTTOM", UIParent, "BOTTOM", vx, 0)
        g.guideV:Show()
    else
        g.guideV:Hide()
    end
    if hy then
        g.guideH:SetPoint("LEFT", UIParent, "LEFT", 0, hy)
        g.guideH:SetPoint("RIGHT", UIParent, "RIGHT", 0, hy)
        g.guideH:Show()
    else
        g.guideH:Hide()
    end
end

-- Lines a value up with the nearest of a set of targets, if one is close.
local function Nearest(values, targets)
    local best, bestD, bestAt
    for _, v in ipairs(values) do
        for _, t in ipairs(targets) do
            local d = math.abs(v - t)
            if d <= PANEL_ALIGN and (not bestD or d < bestD) then
                best, bestD, bestAt = t - v, d, t
            end
        end
    end
    return best, bestAt
end

-- What a piece can line up with, along one axis: the screen's middle line,
-- the other pieces being placed, the kit buttons and (v38) the kits' button
-- bars (edges and middles). ex (v38, for a bar or a floating button being
-- dragged in edit mode): { kit = , bars = that kit's bars to use, skip = a
-- bar to leave out }.
local function Targets(skip, vertical, ex)
    local list = { 0 }
    local function AddBox(x, y, hw, hh)
        if not x then return end
        local c, half = vertical and x or y, vertical and hw or hh
        list[#list + 1] = c - half
        list[#list + 1] = c
        list[#list + 1] = c + half
    end
    local function Add(f)
        if not (f and f:IsVisible()) then return end
        AddBox(Box(f))
    end
    for _, key in ipairs(moverOrder) do
        local m = movers[key]
        if key ~= skip and m.placing and m.frame then Add(m.frame()) end
    end
    for _, kit in ipairs(C.kits or {}) do
        if kit.built then
            Add(kit.kit)
            if kit.cfg.bars then
                local bars = ex and ex.kit == kit and ex.bars or kit:Bars()
                for _, bar in ipairs(bars) do
                    if not (ex and bar == ex.skip) then AddBox(kit:BarExtent(bar)) end
                end
            end
        end
    end
    return list
end

-- A piece dragged so its middle would be at (x, y): where it goes, and the
-- guide lines to show (or nil). ex: as Targets'.
local function Snap(key, x, y, hw, hh, ex)
    local step, snapping = PlaceCfg()
    if not snapping or IsShiftKeyDown() then return x, y end
    local dx, gx = Nearest({ x - hw, x, x + hw }, Targets(key, true, ex))
    local dy, gy = Nearest({ y - hh, y, y + hh }, Targets(key, false, ex))
    -- (otherwise its left and top edges on the grid)
    if dx then x = x + dx else x = Round(x - hw, step) + hw end
    if dy then y = y + dy else y = Round(y + hh, step) - hh end
    return x, y, gx, gy
end

-- Every piece being placed, done (Done, Esc, or Move everything again).
function C.EndPlacing()
    for _, key in ipairs(moverOrder) do
        local m = movers[key]
        if m.placing then
            local ok, err = pcall(m.done or function() m.test(false) end)
            if not ok then geterrorhandler()(err) end
            m.placing = nil
        end
    end
    C.MoveUI()
end

local function SmallButton(parent, text, w, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

-- The grid size and Snap, along the foot of a bar from x (v38: the placing
-- bar's and edit mode's, both the reminder panel's settings, so they're the
-- same everywhere). Returns a function that shows what they're set to now.
local GRID_SIZES = { 8, 16, 24, 32 }
local function GridControls(bar, x)
    local grid = SmallButton(bar, "", 80, nil)
    grid:SetPoint("BOTTOMLEFT", x, 10)
    local snap = CreateFrame("Button", nil, bar)
    snap:SetSize(84, 22)
    snap:SetPoint("BOTTOMLEFT", x + 88, 10)
    local box = CreateFrame("Frame", nil, snap)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 2, 0)
    Well(box, 0.7)
    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("CENTER", 1, 0)
    tick:SetSize(22, 22)
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetVertexColor(1, 0.85, 0.4)
    local label = snap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(Loc["Snap"])
    local function Paint()
        local step, snapping = PlaceCfg()
        grid:SetText((Loc["Grid %s"]):format(step))
        tick:SetShown(snapping)
    end
    -- Grid size: steps through the sizes.
    grid:SetScript("OnClick", function()
        local step, _, p = PlaceCfg()
        local i = 1
        for n, g in ipairs(GRID_SIZES) do if g == step then i = n end end
        p.grid = GRID_SIZES[i % #GRID_SIZES + 1]
        if C.PanelCfg() == p then C.SharePanel(p) end
        C.DrawGrid()
        Paint()
    end)
    snap:SetScript("OnClick", function()
        local _, snapping, p = PlaceCfg()
        p.snap = not snapping
        if C.PanelCfg() == p then C.SharePanel(p) end
        Paint()
    end)
    return Paint
end

local function BuildPlaceBar()
    local bar = OptPanel("Frame", "KitCoreMoveBar", UIParent)
    bar:SetSize(360, 64)
    bar:SetPoint("TOP", 0, -20)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "KitCoreMoveBar") end -- Esc closes it

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -9)
    local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", title, "RIGHT", 10, 0)
    hint:SetText(Loc["Drag to move, Shift for free"])

    local paintGrid = GridControls(bar, 12) -- (grid size and Snap)
    local done = SmallButton(bar, Loc["Done"], 70, function() bar:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -12, 10)
    bar:Hide()
    -- (Esc or Done: every piece finished. Set only now: a new frame starts
    -- shown, so the Hide above would otherwise end the placing it was built for.)
    bar:SetScript("OnHide", function()
        if not placeUI.quiet then C.EndPlacing() end
    end)

    placeUI = { bar = bar }
    C.placeUI = placeUI
    function placeUI.paint()
        paintGrid()
        -- The title says what's being placed: one piece by name, or several.
        local names = {}
        for _, key in ipairs(moverOrder) do
            local m = movers[key]
            if m.placing then names[#names + 1] = m.label or key end
        end
        if #names == 1 then
            title:SetText((Loc["Placing %s"]):format(names[1]))
        else
            title:SetText(Loc["Moving everything"])
        end
    end
end

C.Place = {}
C.Place.Box, C.Place.Cursor = Box, Cursor

-- A piece starts or stops being placed: the grid and bar show while any is,
-- and pieces being placed sit over the grid's shade.
function C.Place.Update(key, on)
    local m = movers[key]
    if m then
        m.placing = on and true or nil
        local f = m.frame and m.frame()
        if f and not InCombatLockdown() then f:SetFrameStrata(on and "DIALOG" or (m.strata or "MEDIUM")) end
    end
    C.MoveUI()
end

-- (v38) What's on screen while things move. The grid, while anything is
-- being placed or a layout edited. One bar at the top: edit mode's while a
-- layout is being edited, placing or not (its Done ends both), otherwise the
-- placing bar. With a layout being edited the grid goes under the kits, so
-- its shade doesn't dim the kit; pieces being placed sit over it either way.
function C.MoveUI()
    local placing, editing = AnyPlacing(), C.editKit ~= nil
    if placing or editing then
        C.grid = C.grid or BuildGrid()
        C.grid:SetFrameStrata(editing and "LOW" or "HIGH")
        C.DrawGrid()
        C.Guide(nil, nil)
        C.grid:Show()
    elseif C.grid then
        C.Guide(nil, nil)
        C.grid:Hide()
    end
    if placing and not editing then
        if not placeUI then BuildPlaceBar() end
        placeUI.paint()
        if not placeUI.bar:IsShown() then placeUI.bar:Show() end
    elseif placeUI and placeUI.bar:IsShown() then
        placeUI.quiet = true -- (out of the way, not Done: the placing goes on)
        placeUI.bar:Hide()
        placeUI.quiet = nil
    end
    if editing and C.editBar and C.editBar.paint then C.editBar.paint() end
end

-- Dragging a piece: frame is what's dragged; move(x, y) puts its middle at
-- (x, y) in UI units from the middle of the screen (and saves it).
function C.Place.Begin(key, frame, move)
    if InCombatLockdown() or not frame then return end
    local x0, y0 = Box(frame)
    if not x0 then return end
    local mx, my = Cursor()
    local d = { key = key, frame = frame, move = move, offX = x0 - mx, offY = y0 - my, downAt = { mx, my } }
    placeDrag = d
    frame:SetScript("OnUpdate", function()
        local x, y = Cursor()
        if not d.moved and math.abs(x - d.downAt[1]) + math.abs(y - d.downAt[2]) < 3 then return end
        d.moved = true
        local _, _, hw, hh = Box(frame)
        local nx, ny, gx, gy = Snap(key, x + d.offX, y + d.offY, hw, hh)
        local sw, sh = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        nx = math.max(-sw + hw, math.min(sw - hw, nx))
        ny = math.max(-sh + hh, math.min(sh - hh, ny))
        move(nx, ny)
        C.Guide(gx, gy)
    end)
end

-- The drag ends. Returns whether it moved (a plain click didn't).
function C.Place.Stop()
    local d = placeDrag
    placeDrag = nil
    if d and d.frame then d.frame:SetScript("OnUpdate", nil) end
    C.Guide(nil, nil)
    return d and d.moved or false
end

-- Move everything: every piece in use, placed at once (or, if anything is
-- being placed, all of it done).
function C.MoveAll(kit)
    if AnyPlacing() then
        -- (and a layout edited along with them: edit mode's end ends the placing)
        if C.editKit then C.editKit:SetEdit(false) else C.EndPlacing() end
        return
    end
    if InCombatLockdown() then
        kit:Print(Loc["Things can only be moved out of combat."], true)
        return
    end
    local n = 0
    C.movingAll = true
    for _, key in ipairs(moverOrder) do
        local m = movers[key]
        local ok, can = pcall(m.can or function() return true end)
        if ok and can and m.test then
            local ok2, err = pcall(m.test, true)
            if not ok2 then geterrorhandler()(err) end
            n = n + 1
        end
    end
    C.movingAll = nil
    -- (v38) The kit's own layout too (its buttons and bars, as Edit layout),
    -- when it has one to edit.
    if kit.cfg.bars and not kit.editing then kit:SetEdit(true, true) end
    if n == 0 and not kit.editing then
        kit:Print(Loc["Nothing to move: turn on the reminder panel or a kit's timers first. The kits themselves move by dragging them."], true)
    else
        C.MoveUI()
    end
end

-- The reminder panel is a piece like any other.
function C.SetPanelUnlocked(on)
    local f = C.panel
    if not f or InCombatLockdown() then return end
    on = on and true or false
    C.panelUnlocked = on
    f:EnableMouse(on)
    f.edit:SetShown(on)
    if not on then f:SetScript("OnUpdate", nil) end
    C.Place.Update("panel", on)
    C.PanelLayout()
end

C.RegisterMover("panel", {
    label = Loc["the reminder panel"],
    frame = function() return C.panel end,
    can = function() return C.PanelOn() and C.panel ~= nil end,
    test = function(on) C.SetPanelUnlocked(on) end,
})

function C.TogglePanelUnlocked(kit)
    if InCombatLockdown() then
        kit:Print(Loc["The reminder panel can only move out of combat."], true)
        return
    end
    if not C.PanelOn() then
        kit:Print(Loc["Turn on the reminder panel for a kit first (its Settings > Reminder panel)."], true)
        return
    end
    C.SetPanelUnlocked(not C.panelUnlocked)
    if kit.optionsUI then kit:PaintOptions() end
end


---------------------------------------------------------------------------
-- What goes in it, and where
---------------------------------------------------------------------------

-- Whether a slot goes in the panel with the kit closed (panel on, ticked).
function Kit:PanelAssigned(slot)
    if slot.noPanel or not slot.Pop or not self:PanelOn() then return false end
    local t = self.db and self.db.panelSlots
    return t and t[slot.key] and true or false
end

function Kit:PanelDefault(slot)
    if slot.panelDefault ~= nil then return slot.panelDefault and true or false end
    return slot.Pop and true or false
end

-- A slot's scale in the panel: every slot there, small reminder buttons
-- included, fills a full cell (PANEL_BASE at the panel's Button size), the
-- same size on screen for every kit.
function C.PanelScale(kit, btn)
    local _, _, size = PanelValues()
    local w = btn and btn:GetWidth() or 0
    if w <= 0 then w = ((btn and btn.isSmall) and 22 or kit.BTN) * (kit.db.buttonSize or 1) end
    return size * (PANEL_BASE / w) * UIParent:GetEffectiveScale() / kit.holder:GetEffectiveScale()
end

-- Lay the panel out: every kit's reminders in it (kit.panelList, from its
-- last refresh) in cells, each copy's spot from the panel's centre
-- (panelX/Y, in the copy's own units at the panel's size), the panel sized
-- to its cells; then each kit puts its copies there. Out of combat only.
function C.PanelLayout()
    local f = C.panel
    if not f or C.panelBusy then return end
    if InCombatLockdown() then C.panelPending = true return end
    C.panelBusy = true
    local ok, err = pcall(function()
        local on = C.PanelOn()
        local _, corner, size, gap, per, column, middle = PanelValues()
        local items = {}
        for _, kit in ipairs(C.kits or {}) do
            for _, btn in ipairs(on and kit.built and kit.panelList or {}) do
                local twin = kit:PanelTwin(btn)
                if twin then items[#items + 1] = { btn = twin, kit = kit } end
            end
        end
        -- The box: "per" cells along, as many lines as it takes (at least one).
        local lines = math.max(1, math.ceil(#items / per))
        local cols, rows = per, lines
        if column then cols, rows = lines, per end
        local cell = PANEL_BASE * size
        local step = cell + gap
        local w = cols * step - gap + PANEL_PAD * 2
        local h = rows * step - gap + PANEL_PAD * 2
        f:SetSize(w, h)
        C.PlacePanel() -- (the corner stays put; it grows away from it)
        local cx, cy = CORNERS[corner][1], CORNERS[corner][2]
        local pe = f:GetEffectiveScale()
        for i, it in ipairs(items) do
            local along, across = (i - 1) % per, math.floor((i - 1) / per)
            if middle then
                -- Centred in its line: the line's buttons spread evenly
                -- either side of the middle (half a cell over when even).
                local inLine = math.min(per, #items - across * per)
                along = along + (per - inLine) / 2
            end
            local col, row = along, across
            if column then col, row = across, along end
            if cx > 0 then col = cols - 1 - col end -- (from the right)
            if cy < 0 then row = rows - 1 - row end -- (from the bottom)
            local x = PANEL_PAD + col * step + cell / 2 - w / 2
            local y = h / 2 - (PANEL_PAD + row * step + cell / 2)
            local be = it.kit.holder:GetEffectiveScale() * C.PanelScale(it.kit, it.btn)
            it.btn.panelX, it.btn.panelY = x * pe / be, y * pe / be
        end
        -- While placing it: the size, and faint cells to see the grid it fills.
        local edit = f.edit
        edit.size:SetText(("%d x %d"):format(cols, rows))
        local n = 0
        if C.panelUnlocked then
            for row = 0, rows - 1 do
                for col = 0, cols - 1 do
                    n = n + 1
                    local t = edit.cells[n]
                    if not t then
                        t = edit:CreateTexture(nil, "ARTWORK")
                        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.1)
                        edit.cells[n] = t
                    end
                    t:ClearAllPoints()
                    t:SetSize(cell, cell)
                    t:SetPoint("TOPLEFT", edit, "TOPLEFT", PANEL_PAD + col * step, -(PANEL_PAD + row * step))
                    t:Show()
                end
            end
        end
        for i = n + 1, #edit.cells do edit.cells[i]:Hide() end
        for _, kit in ipairs(C.kits or {}) do
            if kit.built then kit:PlacePanelSlots() end
        end
    end)
    C.panelBusy = nil
    if not ok then
        local h = geterrorhandler and geterrorhandler()
        if h then h(err) end
    end
end

-- A slot's copy in the panel (made the first time, out of combat): a
-- full-size secure button that does what the slot does (its click
-- attributes are copied over whenever they change out of combat) and looks
-- as it does (MirrorTwin, on every paint), but never moves with the kit.
-- So the panel stays as it is while the kit opens and closes, in combat
-- too; the slot itself only shows with the kit open.
local TWIN_KEYS = { "type", "spell", "item", "macro", "macrotext", "unit", "action",
    "shift-type1", "shift-spell1", "shift-item1", "shift-macrotext1" }

function Kit:CopyTwinAttributes(btn)
    local t = btn.twin
    if not t or InCombatLockdown() then return end
    for _, k in ipairs(TWIN_KEYS) do t:SetAttribute(k, btn:GetAttribute(k)) end
end

function Kit:PanelTwin(btn)
    if btn.twin then return btn.twin end
    if InCombatLockdown() then return nil end
    local t = self:MakeItemButton(self.prefix .. "Panel_" .. btn.slot.key, self.holder, true)
    t:SetFrameStrata("MEDIUM")
    t:SetFrameLevel(12)
    t.src, t.isTwin, t.atPanel = btn, true, true -- (atPanel: not part of the kit's own area)
    t.cooldown = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
    t.cooldown:SetAllPoints()
    Try(t.cooldown.SetDrawEdge, t.cooldown, false)
    t.note = t:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    t.note:SetPoint("TOP", t, "BOTTOM", 0, -1)
    self:AddGlow(t, "glow_ring", 1.6)
    self:ApplyShape(t)
    local flyHere = btn.fly and btn.slot.panelFlyout
    self:HoverTip(t, function(b)
        local slot = btn.slot
        self:TipOwner(b)
        if slot.Tooltip then slot.Tooltip(self, btn) else GameTooltip:AddLine(slot.label) end
        if flyHere then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(slot.flyoutHint or Loc["Right-click: choose"], 0.3, 1, 0.4)
        end
        GameTooltip:Show()
    end)
    -- Right-click: the slot's drawer, beside the copy (v32, slot.panelFlyout).
    if flyHere then
        t:SetAttribute("type2", "kcflyat")
        t:SetAttribute("_kcflyat", function()
            if self:Debounced() then self:OpenFlyoutAt(btn, t) end
        end)
    end
    t:Hide()
    btn.twin = t
    btn:HookScript("OnAttributeChanged", function(b, name)
        for _, k in ipairs(TWIN_KEYS) do
            if k == name then self:CopyTwinAttributes(b) break end
        end
    end)
    self:CopyTwinAttributes(btn)
    return t
end

-- The copy looks as the slot does: icon, greyed or tinted, count, note,
-- glow and cooldown.
function Kit:MirrorTwin(btn)
    local t = btn.twin
    if not (t and t:IsShown()) then return end
    local si, ti = btn.icon, t.icon
    if si and ti then
        ti:SetTexture(si:GetTexture())
        Try(ti.SetDesaturated, ti, si.IsDesaturated and si:IsDesaturated() or false)
        ti:SetVertexColor(si:GetVertexColor())
        ti:SetAlpha(si:GetAlpha())
    end
    if t.count then t.count:SetText(btn.count and btn.count:GetText() or "") end
    t.note:SetText(btn.note and btn.note:GetText() or "")
    if btn.glow and btn.glow:IsShown() then
        local r, g, b = btn.glow:GetVertexColor()
        self:SetGlow(t, true, { r, g, b })
    else
        self:SetGlow(t, false)
    end
    local ok, start, dur = pcall(btn.cooldown.GetCooldownTimes, btn.cooldown)
    if ok and start and dur and dur > 0 then
        t.cooldown:SetCooldown(start / 1000, dur / 1000)
    else
        t.cooldown:Clear()
    end
end

-- Put this kit's copies in their cells (at the panel's size) and show them;
-- hide the ones whose reminder isn't in the panel any more.
function Kit:PlacePanelSlots()
    local panel = C.panel
    for _, btn in pairs(self.slots) do
        local t = btn.twin
        if t then
            if btn.inPanel and panel and t.panelX and C.PanelOn() then
                local scale = C.PanelScale(self, t)
                if math.abs(t:GetScale() - scale) > 0.001 then t:SetScale(scale) end
                if t.panelAtX ~= t.panelX or t.panelAtY ~= t.panelY then
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", panel, "CENTER", t.panelX, t.panelY)
                    t.panelAtX, t.panelAtY = t.panelX, t.panelY
                end
                self:CopyTwinAttributes(btn)
                t:Show()
                self:PaintSlot(btn)
            elseif t:IsShown() then
                t:Hide()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Bars (from v23), for a kit with cfg.bars
--
-- In the kit's edit mode every button that can be pinned can be dragged.
-- Dropped away from the kit it floats there on its own; drop another on it
-- and the two make a bar (a row if it landed beside it, a column if above
-- or below), and after that a button dropped on the bar goes in where it
-- landed: at either end or between two. Dropped on the kit, a button goes
-- back to its place there. There's no limit to the bars or what's on them.
--
-- A button on a bar is always shown, kit open or closed, and it's the slot
-- itself, moved: its drawer, its corner button, its glow, its count and its
-- key binding all come along. The kit lays itself out as if that slot
-- weren't there (the ring closes up, an edge column loses it), and pinning
-- and the reminder panel don't apply to it while it's on a bar.
--
-- The bars are saved for the character (cdb.bars), each by its middle from
-- the screen's centre, so they stay put when the kit is moved. The buttons
-- hang from the kit's holder (which covers the screen) rather than from the
-- kit button, and the kit button's combat switch skips them ("kcbar"), so
-- opening, closing and moving the kit in combat leaves them where they are.
-- Like everything secure, they only move out of combat: edit mode ends when
-- a fight starts.
--
-- While a button is being dragged the layout is shown as it would be if you
-- let go (kit.barPreview stands in for cdb.bars): the others make room, the
-- dragged button sits faintly in its new place, and a copy of it follows
-- the mouse.
---------------------------------------------------------------------------

local BAR_PAD = 7 -- round a bar's buttons, inside its box (edit mode)

-- Can this slot go on a bar?
function Kit:CanBar(slot)
    return self.cfg.bars and slot and not slot.noPin and not slot.noBar and true or false
end

-- The bars as they are (or, while a button is being dragged, as they'd be).
function Kit:Bars()
    if not self.cfg.bars then return {} end
    return self.barPreview or (self.cdb and self.cdb.bars) or {}
end

-- Is this slot on a bar (as of the last refresh)?
function Kit:OnBar(key)
    local btn = self.slots[key]
    return btn and btn.kcBar and true or false
end

-- The saved bars, tidied: only slots this kit has and lets on a bar, each
-- once, and no empty bars.
function Kit:CleanBars()
    local cdb = self.cdb
    if not cdb then return end
    local out, seen = {}, {}
    if self.cfg.bars and type(cdb.bars) == "table" then
        for _, bar in ipairs(cdb.bars) do
            if type(bar) == "table" and type(bar.keys) == "table" then
                local keys = {}
                for _, key in ipairs(bar.keys) do
                    if not seen[key] and self:CanBar(self.slotByKey[key]) then
                        seen[key] = true
                        keys[#keys + 1] = key
                    end
                end
                if #keys > 0 then
                    out[#out + 1] = { x = tonumber(bar.x) or 0, y = tonumber(bar.y) or 0,
                        dir = bar.dir == "col" and "col" or "row", keys = keys }
                end
            end
        end
    end
    cdb.bars = out
end

-- A copy of some bars without one slot (and without any bar that leaves empty).
function Kit:BarsWithout(bars, key)
    local out = {}
    for _, bar in ipairs(bars or {}) do
        local keys = {}
        for _, k in ipairs(bar.keys) do
            if k ~= key then keys[#keys + 1] = k end
        end
        if #keys > 0 then out[#out + 1] = { x = bar.x, y = bar.y, dir = bar.dir, keys = keys } end
    end
    return out
end

-- Which slots are on a bar: each button's kcBar, kept in step with the bars
-- (out of combat, at the start of every refresh). One that has just left a
-- bar forgets where it was put, so the kit's layout anchors it again.
function Kit:MarkBars()
    if not self.cfg.bars then return end
    local on = {}
    for _, bar in ipairs(self:Bars()) do
        for _, key in ipairs(bar.keys) do on[key] = true end
    end
    for key, btn in pairs(self.slots) do
        local want = on[key] and true or nil
        if btn.kcBar ~= want then
            if sliding[btn] then self:FinishSlide(btn) end
            btn.kcBar = want
            btn.barX, btn.barY = nil, nil
            if not want then
                btn.barGrid = nil
                btn.placedX, btn.placedY = nil, nil
            end
        end
    end
end

-- One cell of a bar (a full slot and the gap), in UIParent units.
function Kit:BarCell()
    return (self.BTN * (self.db.buttonSize or 1) + (tonumber(self.db.barGap) or 4)) * (self.db.scale or 1)
end

-- (v38) A bar's buttons as a box, for lining things up with it: its middle
-- and half-size, in UIParent units from the screen's centre (the buttons'
-- own edges, not edit mode's box round them). nil with none showing, or
-- with the kit hidden.
function Kit:BarExtent(bar)
    local shown = self:BarShown(bar)
    local n = #shown
    if n == 0 then return nil end
    if not self.editing then
        local btn = self.slots[shown[1]]
        if not (btn and btn:IsVisible()) then return nil end
    end
    local cell, size = self:BarCell(), self:BarButtonSize()
    local long = (n - 1) * cell + size
    if bar.dir == "col" then return bar.x, bar.y, size / 2, long / 2 end
    return bar.x, bar.y, long / 2, size / 2
end

-- (v38) One button on a bar, across, in UIParent units (a cell without its gap).
function Kit:BarButtonSize()
    return self:BarCell() - (tonumber(self.db.barGap) or 4) * (self.db.scale or 1)
end

-- A bar's slots that are there right now (a hidden one leaves no gap).
function Kit:BarShown(bar)
    local shown = {}
    for _, key in ipairs(bar.keys) do
        local btn = self.slots[key]
        if btn and not btn.hidden then shown[#shown + 1] = key end
    end
    return shown
end

-- Where the i-th of n buttons on a bar sits (UIParent units from the
-- screen's centre): a row reads left to right, a column top to bottom, both
-- centred on the bar's middle.
function Kit:BarSpot(bar, i, n, cell)
    local off = (i - (n + 1) / 2) * cell
    if bar.dir == "col" then return bar.x, bar.y - off end
    return bar.x + off, bar.y
end

-- The kit button's middle, in UIParent units from the screen's centre.
function Kit:KitCentreUI()
    local x, y = self.kit:GetCenter()
    if not x then return nil end
    local k = self.kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * k - UIParent:GetWidth() / 2, y * k - UIParent:GetHeight() / 2
end

-- Keep a bar's middle on the screen.
function Kit:ClampBar(x, y)
    local hw, hh = UIParent:GetWidth() / 2 - 20, UIParent:GetHeight() / 2 - 20
    return math.max(-hw, math.min(hw, x)), math.max(-hh, math.min(hh, y))
end

-- Put every button that's on a bar in its place there. Out of combat only.
-- glide: ones that move slide over (Kit Dock's glide) instead of jumping.
function Kit:PlaceBars(glide)
    if not self.cfg.bars or not self.built or InCombatLockdown() then return end
    local s = self.db.scale or 1
    local cell = self:BarCell()
    local kx, ky = self:KitCentreUI()
    local D = self.Dock
    for _, bar in ipairs(self:Bars()) do
        local shown = self:BarShown(bar)
        -- Drawers open away from the bar's line, toward the middle of the screen.
        local grid
        if bar.dir == "col" then grid = bar.x > 0 and "left" or "right" else grid = bar.y > 0 and "down" or "up" end
        for i, key in ipairs(shown) do
            local btn = self.slots[key]
            if btn.kcBar then
                local ux, uy = self:BarSpot(bar, i, #shown, cell)
                local x, y = ux / s, uy / s -- (a slot's own units: it's scaled by the kit's size)
                btn.barGrid = grid
                -- Where that is from the kit, for the drawer's fit on screen.
                if kx then btn.placedX, btn.placedY = (ux - kx) / s, (uy - ky) / s end
                if btn.barX ~= x or btn.barY ~= y then
                    local ox, oy, os
                    if glide and D and D.Glide and btn:IsShown() then
                        ox, oy = btn:GetCenter()
                        os = btn:GetEffectiveScale()
                    end
                    if D and D.StopTween then D.StopTween(btn) end
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", self.holder, "CENTER", x, y)
                    btn.barX, btn.barY = x, y
                    if ox then D.Glide(btn, ox, oy, os) end
                end
            end
        end
    end
end

-- Back to how the kit started: every button off the bars, and the kit's
-- own zones in their usual order.
function Kit:ResetLayout()
    if not self.cfg.bars then return end
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."], true) return end
    C.StopEditDrag(true)
    self.cdb.bars = {}
    self.cdb.zones = nil
    self:ApplyZones()
    self:Refresh(false)
    if self.Dock and self.Dock.Layout then self.Dock.Layout() end
    self:Print(Loc["Layout reset: every button is back in its usual place."])
    self:SettingsChanged()
end
Kit.ResetBars = Kit.ResetLayout

---------------------------------------------------------------------------
-- Zones (v23): the places on the kit itself (cfg.zones: a ring, a row)
-- whose buttons can be dragged from one to another, and into any order, in
-- edit mode. What's saved (cdb.zones) is just each zone's list of slots;
-- the kit's own tables are filled from the lists (cfg.OnZones), so its
-- layout, divider, edge columns and reminders all follow without knowing.
-- A slot on a bar keeps its place in its zone's list: that's where it goes
-- back to when it's dropped on the kit's icon.
--
-- From v31 a zone can be one of small buttons (zone.small: a ring of them
-- under the kit, say). Then every zone's slots take its size, so a small
-- button dragged out to a full-size zone or onto a bar becomes a full slot,
-- and one dragged back becomes small again (SetSlotSmall), even while the
-- drag is only being shown. zone.only keeps a zone to the slots it lists.
---------------------------------------------------------------------------

local function CopyLists(lists)
    local out = {}
    for k, keys in pairs(lists or {}) do
        out[k] = {}
        for i, key in ipairs(keys) do out[k][i] = key end
    end
    return out
end

-- The kit's rings as a list (cfg.ring may be one ring or several).
function Kit:Rings()
    local rings = self.cfg.ring
    if rings and rings.keys then rings = { rings } end
    return rings or {}
end

-- Each zone's starting slots (noted once, before anything is moved).
function Kit:ZoneDefaults()
    if self.zoneDefaults then return self.zoneDefaults end
    local d, home = {}, {}
    for _, z in ipairs(self.cfg.zones or {}) do
        local ring = z.ring and self:Rings()[z.ring]
        d[z.key] = {}
        for i, key in ipairs(ring and ring.keys or z.keys or {}) do
            d[z.key][i] = key
            home[key] = z.key
        end
    end
    self.zoneDefaults, self.zoneHome = d, home
    return d
end

-- Can this slot go in this zone? (zone.only, v31: just the slots it lists)
local function ZoneTakes(z, key)
    if not z.only then return true end
    for _, k in ipairs(z.only) do
        if k == key then return true end
    end
    return false
end

-- The zones' lists as they are (or, while a button is being dragged, as they'd be).
function Kit:Zones()
    return self.zonePreview or (self.cdb and self.cdb.zones) or self:ZoneDefaults()
end

-- The saved lists, tidied: every slot that belongs to a zone in exactly one
-- list (one that's missing, or in a zone that doesn't take it, goes back to
-- the zone it started in). Nothing is kept when they match the starting
-- layout.
function Kit:CleanZones()
    local cdb = self.cdb
    if not cdb then return end
    if not (self.cfg.bars and self.cfg.zones) then cdb.zones = nil return end
    local defaults = self:ZoneDefaults()
    local saved = type(cdb.zones) == "table" and cdb.zones or nil
    if not saved then cdb.zones = nil return end
    local out, seen = {}, {}
    for _, z in ipairs(self.cfg.zones) do
        out[z.key] = {}
        for _, key in ipairs(type(saved[z.key]) == "table" and saved[z.key] or {}) do
            if self.zoneHome[key] and not seen[key] and ZoneTakes(z, key) then
                seen[key] = true
                table.insert(out[z.key], key)
            end
        end
    end
    local same = true
    for _, z in ipairs(self.cfg.zones) do
        for _, key in ipairs(defaults[z.key]) do
            if not seen[key] then table.insert(out[z.key], key) end
        end
        if #out[z.key] ~= #defaults[z.key] then same = false end
        for i, key in ipairs(defaults[z.key]) do
            if out[z.key][i] ~= key then same = false end
        end
    end
    cdb.zones = not same and out or nil
end

-- Hand the lists to the kit, and note which zone each slot is in now.
function Kit:ApplyZones()
    if not (self.cfg.bars and self.cfg.zones) then return end
    local lists = self:Zones()
    self.zonesCustom = lists ~= self:ZoneDefaults()
    local now = {}
    for _, z in ipairs(self.cfg.zones) do
        for _, key in ipairs(lists[z.key] or {}) do now[key] = z end
    end
    self.zoneNow = now
    self:SizeZoneSlots()
    if self.cfg.OnZones then self.cfg.OnZones(self, CopyLists(lists)) end
end

-- With a zone of small buttons (zone.small, v31), each zone's slots take its
-- size: small there, full slots in the others. A slot on a bar is a full
-- one wherever its zone is (the bars' cells are full size), and so is one
-- that's only being dragged onto a bar (kit:Bars() is the preview then).
-- Before the slots are made this only sets slot.small, which they're made
-- from; after, the buttons change (SetSlotSmall), out of combat. The next
-- refresh catches up after a fight.
function Kit:SizeZoneSlots()
    local zones, now = self.cfg.zones, self.zoneNow
    if not (zones and now) then return end
    local any = false
    for _, z in ipairs(zones) do
        if z.small then any = true end
    end
    if not any then return end
    local onBar = {}
    for _, bar in ipairs(self:Bars()) do
        for _, key in ipairs(bar.keys or {}) do onBar[key] = true end
    end
    for key, z in pairs(now) do
        local slot = self.slotByKey[key]
        if slot then
            local small = (z.small and not onBar[key]) and true or false
            slot.small = small or nil
            local btn = self.slots[key]
            if btn and not InCombatLockdown() then self:SetSlotSmall(btn, small) end
        end
    end
end

-- Copies of some lists without one slot, and with it put in a zone.
function Kit:ZonesWithout(lists, key)
    local out = CopyLists(lists)
    for _, keys in pairs(out) do
        for i = #keys, 1, -1 do
            if keys[i] == key then table.remove(keys, i) end
        end
    end
    return out
end

function Kit:ZonesWith(lists, key, target)
    local out = CopyLists(lists)
    local keys = out[target.zone]
    if keys then table.insert(keys, math.max(1, math.min(#keys + 1, target.at or (#keys + 1))), key) end
    return out
end

-- A zone's slots that are on the kit right now (not hidden, not on a bar).
function Kit:ZoneShown(keys)
    local shown = {}
    for _, key in ipairs(keys or {}) do
        local btn = self.slots[key]
        if btn and not btn.hidden and not btn.kcBar then shown[#shown + 1] = key end
    end
    return shown
end

-- Where in a list to put a slot so it comes after so many of its shown ones.
local function ListPlace(keys, shown, after)
    local want = after < #shown and shown[after + 1] or shown[#shown]
    for i, key in ipairs(keys) do
        if key == want then return after < #shown and i or i + 1 end
    end
    return #keys + 1
end

-- The mouse (UIParent units from the screen's centre) in the kit's own
-- layout: from its middle, in slot units, before the layout is turned or
-- spread. nil on a screen edge or shrunk on the dock, where the zones
-- aren't laid out as a ring and a row.
local UNFACE = {
    up = function(x, y) return x, y end,
    down = function(x, y) return x, -y end,
    left = function(x, y) return -y, -x end,
    right = function(x, y) return -y, x end,
}
function Kit:LayoutPoint(mx, my)
    if self.edgeSide or self.compactAngle or self.parked then return nil end
    local kx, ky = self:KitCentreUI()
    if not kx then return nil end
    local k = (self.db.scale or 1) * (self.db.spread or 1)
    return UNFACE[self:Facing()]((mx - kx) / k, (my - ky) / k)
end

-- Which zone a dragged slot would land in with the mouse there, and where:
-- { zone = zoneKey, at = i } (before the list's i-th key), or nil.
-- lists: the zones without that slot.
function Kit:ZoneTarget(lists, key, mx, my)
    if not (self.cfg.zones and lists and self.zoneHome and self.zoneHome[key]) then return nil end
    local lx, ly = self:LayoutPoint(mx, my)
    if not lx then return nil end
    local BTN = self.BTN
    -- Rows first: a wide ring's ends can reach down beside one.
    for _, z in ipairs(self.cfg.zones) do
        if z.y and lists[z.key] and ZoneTakes(z, key) then
            local shown = self:ZoneShown(lists[z.key])
            local n = #shown
            local step = z.step or (BTN + 8)
            if math.abs(ly - z.y) <= BTN / 2 + 10 and math.abs(lx) <= math.max(n + 1, 3) * step / 2 + 8 then
                local after = math.max(0, math.min(n, math.floor(lx / step + n / 2 + 0.5)))
                return { zone = z.key, at = ListPlace(lists[z.key], shown, after) }
            end
        end
    end
    -- A ring: its band round the kit (ZoneBands), at any angle. Past either
    -- end of the ring's buttons it goes on that end.
    local bands = self:ZoneBands()
    local d = math.sqrt(lx * lx + ly * ly)
    for _, z in ipairs(self.cfg.zones) do
        local ring = z.ring and self:Rings()[z.ring]
        local band = bands[z.key]
        if ring and band and lists[z.key] and ZoneTakes(z, key) and d >= band.lo and d <= band.hi then
            local shown = self:ZoneShown(lists[z.key])
            local n = #shown
            -- (as it would be with this one on it: right round, if that empties the row)
            local step, _, mid = self:RingGeo(ring, n + 1, self:BelowEmpty(lists))
            local a = math.deg(math.atan2(ly, lx))
            while a < mid - 180 do a = a + 360 end
            while a > mid + 180 do a = a - 360 end
            local after = n
            if step ~= 0 then after = math.floor((a - mid) / step + (n + 2) / 2 + 0.5) - 1 end
            after = math.max(0, math.min(n, after))
            return { zone = z.key, at = ListPlace(lists[z.key], shown, after) }
        end
    end
    return nil
end

-- Each ring zone's drop band (v35), in the kit's layout units (before its
-- spread): [zoneKey] = { lo = , hi = }, how far out from the kit's middle it
-- starts and ends. A drop anywhere in the band, at any angle, goes on that
-- ring, and edit mode shades the band so you can see where that is. Rings
-- one inside another meet halfway between their radii, so the bands never
-- overlap; the innermost starts just outside the kit's own icon (a drop on
-- the icon still puts a button back), the outermost ends most of a button
-- past its ring.
function Kit:ZoneBands()
    local rings = {}
    for _, z in ipairs(self.cfg.zones or {}) do
        local ring = z.ring and self:Rings()[z.ring]
        if ring then rings[#rings + 1] = { key = z.key, r = ring.radius } end
    end
    table.sort(rings, function(a, b) return a.r < b.r end)
    local sp = (self.db and self.db.spread) or 1
    local icon = (self.KIT or 60) / 2 * ((self.db and self.db.kitSize) or 1) / sp + 2
    local BTN = self.BTN or 37
    local bands = {}
    for i, e in ipairs(rings) do
        local lo = i > 1 and (rings[i - 1].r + e.r) / 2 or math.max(icon, e.r - BTN * 0.7)
        local hi = rings[i + 1] and (e.r + rings[i + 1].r) / 2 or e.r + BTN * 0.9
        bands[e.key] = { lo = lo, hi = math.max(lo + 1, hi), level = #rings - i + 1 }
    end
    return bands
end

-- A zone's area in edit mode (made the first time): for a ring, its band
-- (ZoneBands) as a shaded disc out to the band's outer edge with a dashed
-- circle round it, an inner ring's disc on top of the outer one's so each
-- band shows as its own shade; for a row, a box. With its name. It hangs
-- from the kit button, so it follows the kit, and sits under the slots.
function Kit:ZoneFrame(z)
    self.zoneFrames = self.zoneFrames or {}
    local f = self.zoneFrames[z.key]
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(1)
    f:EnableMouse(false)
    f.parts = {}
    if z.ring then
        -- (the disc: dark underneath, so a ring inside another hides the
        -- outer one's shade, then the zone's own gold)
        f.base = f:CreateTexture(nil, "BACKGROUND")
        f.base:SetTexture(self.media .. "circle_mask", nil, nil, "LINEAR")
        f.fill = f:CreateTexture(nil, "BORDER")
        f.fill:SetTexture(self.media .. "circle_mask", nil, nil, "LINEAR")
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(self.media .. "zone_ring", nil, nil, "LINEAR")
        f.parts[1] = t
    else
        -- (dark underneath too: it sits over a ring's band where they meet,
        -- and a drop there goes in the row)
        f.base = f:CreateTexture(nil, "BACKGROUND", nil, -1)
        f.base:SetAllPoints()
        f.base:SetColorTexture(0, 0, 0, 0.5)
        f.fill = f:CreateTexture(nil, "BACKGROUND")
        f.fill:SetAllPoints()
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetPoint(e[1])
            t:SetPoint(e[2])
            if e[3] then t:SetWidth(1) else t:SetHeight(1) end
            f.parts[#f.parts + 1] = t
        end
    end
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetText(z.label or z.key)
    f:Hide()
    self.zoneFrames[z.key] = f
    return f
end

-- Edit mode's areas for the kit's zones (v35: each ring's whole drop band
-- shaded, not just an outline). While a button is dragged, the one it would
-- land in is lit, and any that won't take it fade right back.
local ZONE_LINE = 0.965 -- (where zone_ring's line sits: this far from its middle to its edge)
function Kit:PaintZones()
    local zones = self.cfg.zones
    if not zones then return end
    local on = self.editing and not (self.edgeSide or self.compactAngle or self.parked)
    local lists = self:Zones()
    local sp = self.db.spread or 1
    local BTN = self.BTN
    local bands = self:ZoneBands()
    local nRings = 0
    for _ in pairs(bands) do nRings = nRings + 1 end
    local drag = C.editDrag and C.editDrag.kit == self and C.editDrag.kind == "slot" and C.editDrag.moved and C.editDrag.key
    for _, z in ipairs(zones) do
        local f = (on or (self.zoneFrames and self.zoneFrames[z.key])) and self:ZoneFrame(z)
        if f and not on then
            f:Hide()
        elseif f then
            local hot = self.zoneHot == z.key
            local closed = drag and not ZoneTakes(z, drag) -- (dragging one it won't take)
            local ring = z.ring and self:Rings()[z.ring]
            local band = bands[z.key]
            f:SetScale(self.db.scale or 1)
            f:ClearAllPoints()
            f.label:ClearAllPoints()
            if ring and band then
                -- Outer rings underneath, inner ones on top; the rows over them all.
                f:SetFrameLevel(band.level)
                local hi = band.hi * sp
                local size = 2 * hi / ZONE_LINE
                f:SetSize(size, size)
                f:SetPoint("CENTER", self.kit, "CENTER", 0, 0)
                f.base:SetSize(2 * hi, 2 * hi)
                f.base:SetPoint("CENTER")
                f.fill:SetSize(2 * hi, 2 * hi)
                f.fill:SetPoint("CENTER")
                f.parts[1]:SetAllPoints()
                -- (a ring inside another: nearly opaque, so the outer one's shade doesn't show through)
                f.base:SetVertexColor(0, 0, 0, band.level > 1 and 0.8 or 0.45)
                f.fill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], closed and 0 or hot and 0.26 or 0.07)
                if z.track then
                    -- (a ring inside another: its name just beyond its
                    -- buttons, out from the middle of its arc)
                    local mid = math.rad((ring.from + ring.to) / 2)
                    local d = ring.radius * sp + (z.small and 11 or BTN / 2) + 8
                    local lx, ly = self:Face(d * math.cos(mid), d * math.sin(mid))
                    f.label:SetPoint("CENTER", f, "CENTER", lx, ly)
                else
                    local lx, ly = self:Face(0, hi + 8)
                    f.label:SetPoint("CENTER", f, "CENTER", lx, ly)
                end
            else
                f:SetFrameLevel(nRings + 1)
                local n = #self:ZoneShown(lists[z.key])
                local w = math.max(n + 1, 3) * (z.step or (BTN + 8)) * sp + 16
                local h = BTN + 20
                local side = self:Sideways()
                f:SetSize(side and h or w, side and w or h)
                f:SetPoint("CENTER", self.kit, "CENTER", self:Face(0, z.y * sp))
                local lx, ly = self:Face(0, -(h / 2 + 8))
                f.label:SetPoint("CENTER", f, "CENTER", lx, ly)
                f.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], closed and 0 or hot and 0.16 or 0.05)
            end
            local line = closed and 0.15 or hot and 1 or 0.45
            for _, t in ipairs(f.parts) do
                if ring then t:SetVertexColor(1, 0.82, 0.3, line)
                else t:SetColorTexture(1, 0.82, 0.3, line) end
            end
            f.label:SetAlpha(closed and 0.3 or hot and 1 or 0.6)
            f:Show()
        end
    end
end

---------------------------------------------------------------------------
-- Edit mode: dragging buttons on and off bars
---------------------------------------------------------------------------

-- Where a dragged button would land with the mouse at mx, my (UIParent
-- units from the screen's centre). bars: the bars without that button.
--   { bar = n, dir = "row" | "col", at = i }  on bar n, before its i-th key
--   { zone = zoneKey, at = i }                on the kit, in that zone, before its i-th key
--                                             (lists, key: the zones without the button, and its key)
--   { kit = true }                            back on the kit, where it was
--   { new = true, x, y }                      on its own, there
function Kit:BarTarget(bars, mx, my, lists, key)
    local cell = self:BarCell()
    local reach = cell * 0.6
    for bi, bar in ipairs(bars) do
        local shown = self:BarShown(bar)
        local n = #shown
        if n > 0 then
            local dx, dy = mx - bar.x, my - bar.y
            local dir = bar.dir
            local along, across
            if n == 1 then
                -- One button so far: where the second lands says which way the bar runs.
                dir = math.abs(dy) > math.abs(dx) and "col" or "row"
                along, across = cell / 2 + reach, cell / 2 + reach
            else
                along, across = n * cell / 2 + reach, cell / 2 + reach
            end
            local a, c = dx, dy
            if dir == "col" then a, c = -dy, dx end -- (a column reads top to bottom)
            if math.abs(a) <= along and math.abs(c) <= across then
                local after = math.floor(a / cell + n / 2 + 0.5) -- how many of its buttons come before
                after = math.max(0, math.min(n, after))
                -- (as a place among all its keys, hidden ones included)
                local at = #bar.keys + 1
                if after < n then
                    for ki, key in ipairs(bar.keys) do
                        if key == shown[after + 1] then at = ki break end
                    end
                end
                return { bar = bi, dir = dir, at = at }
            end
        end
    end
    -- On one of the kit's zones: into it, there.
    local zone = lists and self:ZoneTarget(lists, key, mx, my)
    if zone then return zone end
    -- On the kit (the open kit's reach round its button): back to its place.
    local kx, ky = self:KitCentreUI()
    if kx then
        local l, r, t, b = self:Reach()
        if mx >= kx - l and mx <= kx + r and my >= ky - b and my <= ky + t then return { kit = true } end
    end
    local x, y = self:ClampBar(mx, my)
    return { new = true, x = x, y = y }
end

-- The bars with the button put where the target says. bars: without it
-- (a copy the caller owns; it's changed and returned).
function Kit:BarsWith(bars, key, target)
    if target.bar and bars[target.bar] then
        local bar = bars[target.bar]
        bar.dir = target.dir or bar.dir
        table.insert(bar.keys, math.max(1, math.min(#bar.keys + 1, target.at or (#bar.keys + 1))), key)
    elseif target.new then
        bars[#bars + 1] = { x = target.x, y = target.y, dir = "row", keys = { key } }
    end
    return bars
end

-- A gold glow on the kit button while a dragged button would drop on it.
function Kit:DropGlow(on)
    local k = self.kit
    if on and not k.kcDrop then
        local t = k:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(self.media .. "glow_ring")
        t:SetBlendMode("ADD")
        t:SetPoint("CENTER")
        t:SetVertexColor(1, 0.82, 0.3)
        k.kcDrop = t
    end
    if k.kcDrop then
        k.kcDrop:SetSize(k:GetWidth() * 1.5, k:GetHeight() * 1.5)
        k.kcDrop:SetShown(on and true or false)
    end
end

-- The cover over one button in edit mode (made the first time, out of
-- combat): it takes the mouse, so a click there never uses the button, and
-- pressing it starts the drag.
function Kit:EditCover(btn)
    local ov = btn.kcEdit
    if not ov then
        ov = CreateFrame("Button", nil, btn)
        ov:SetAllPoints(btn)
        ov:Hide()
        local hl = ov:CreateTexture(nil, "OVERLAY", nil, 7)
        hl:SetTexture(self.media .. "glow_ring")
        hl:SetBlendMode("ADD")
        hl:SetPoint("CENTER")
        hl:SetVertexColor(1, 0.82, 0.3)
        hl:SetAlpha(0.3)
        ov.hl = hl
        ov:SetScript("OnEnter", function(o)
            o.hl:SetAlpha(0.8)
            if C.editDrag then return end
            GameTooltip:SetOwner(o, "ANCHOR_RIGHT")
            GameTooltip:AddLine(btn.slot.label)
            GameTooltip:AddLine(Loc["Drag to move it."], 1, 1, 1)
            GameTooltip:AddLine(btn.kcBar and Loc["Drop it on the kit to put it back."] or Loc["Drop it away from the kit to float it."], 1, 0.82, 0)
            GameTooltip:Show()
        end)
        ov:SetScript("OnLeave", function(o)
            o.hl:SetAlpha(0.3)
            GameTooltip:Hide()
        end)
        ov:SetScript("OnMouseDown", function(_, mouse)
            if mouse == "LeftButton" then C.StartEditDrag(self, btn) end
        end)
        btn.kcEdit = ov
    end
    ov:SetFrameLevel(btn:GetFrameLevel() + 20)
    local w = btn:GetWidth() * (btn.isSmall and 1.7 or 1.6)
    ov.hl:SetSize(w, w)
    return ov
end

function Kit:EditCovers(on)
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        if btn then
            if on and self:CanBar(slot) then
                if btn.kcEdit or not InCombatLockdown() then self:EditCover(btn):Show() end
            elseif btn.kcEdit then
                btn.kcEdit:Hide()
            end
        end
    end
end

-- A bar's box in edit mode: a faint gold box round its buttons, under them,
-- with a tab on top. Dragging either moves the bar.
function Kit:MakeBarBox(i)
    local box = OptPanel("Frame", nil, UIParent)
    box:SetFrameStrata("MEDIUM")
    box:SetFrameLevel(2) -- (under the slots, which sit at 12)
    if box.SetBackdropColor then box:SetBackdropColor(0.78, 0.64, 0.3, 0.12) end
    box:EnableMouse(true)
    local function Down(_, mouse)
        if mouse == "LeftButton" then C.StartBarDrag(self, box) end
    end
    local function Enter(f)
        if C.editDrag then return end
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:AddLine(Loc["Bar"])
        GameTooltip:AddLine(Loc["Drag to move the whole bar. It snaps to the grid; hold Shift to place it freely."], 1, 1, 1)
        GameTooltip:Show()
    end
    local function Leave() GameTooltip:Hide() end
    box:SetScript("OnMouseDown", Down)
    box:SetScript("OnEnter", Enter)
    box:SetScript("OnLeave", Leave)
    local tab = CreateFrame("Button", nil, box)
    tab:SetSize(36, 12)
    tab:SetPoint("BOTTOM", box, "TOP", 0, -2)
    local t = tab:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.7)
    tab:SetScript("OnMouseDown", Down)
    tab:SetScript("OnEnter", Enter)
    tab:SetScript("OnLeave", Leave)
    box:Hide()
    self.barBoxes[i] = box
    return box
end

-- Edit mode's boxes, one round each bar that has a button showing.
function Kit:PaintEdit()
    if not self.editing then return end
    self:PaintZones()
    self.barBoxes = self.barBoxes or {}
    local cell = self:BarCell()
    local n = 0
    for _, bar in ipairs(self:Bars()) do
        local count = #self:BarShown(bar)
        if count > 0 then
            n = n + 1
            local box = self.barBoxes[n] or self:MakeBarBox(n)
            box.bar = bar
            local col = bar.dir == "col"
            box:SetSize((col and 1 or count) * cell + 2 * BAR_PAD, (col and count or 1) * cell + 2 * BAR_PAD)
            box:ClearAllPoints()
            box:SetPoint("CENTER", UIParent, "CENTER", bar.x, bar.y)
            box:Show()
        end
    end
    for i = n + 1, #self.barBoxes do self.barBoxes[i]:Hide() end
end

function Kit:HideBarBoxes()
    for _, box in ipairs(self.barBoxes or {}) do box:Hide() end
    for _, f in pairs(self.zoneFrames or {}) do f:Hide() end
end

-- The copy of the dragged button that follows the mouse.
local function EditGhost(kit)
    local g = C.editGhost
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("TOOLTIP")
        g:EnableMouse(false)
        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetAllPoints()
        if g.CreateMaskTexture then
            local mask = g:CreateMaskTexture()
            mask:SetTexture(kit.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(g.icon)
            g.icon:AddMaskTexture(mask)
        end
        g.ring = g:CreateTexture(nil, "OVERLAY")
        g.ring:SetTexture(kit.media .. "glow_ring")
        g.ring:SetBlendMode("ADD")
        g.ring:SetPoint("CENTER")
        g.ring:SetVertexColor(1, 0.82, 0.3)
        -- (v35) Where it would go, under it: the zone's name, a bar, on its
        -- own, or back in its place.
        g.label = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        g.label:SetPoint("TOP", g, "BOTTOM", 0, -6)
        g.label:SetShadowOffset(1, -1)
        g:Hide()
        C.editGhost = g
    end
    return g
end

-- (v35) The ghost at the size the button would be where it would land
-- (small over a zone of small buttons, full size elsewhere: the button has
-- already changed size for the preview), and its label.
local function SizeGhost(g, btn, text)
    local size = btn:GetWidth() * btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
    g:SetSize(size, size)
    g.ring:SetSize(size * 1.6, size * 1.6)
    g.label:SetText(text or "")
end

-- (v35) A gold ring round the spot a dragged button would land on (the
-- button itself shows there, faint), so it's easy to find among the rest.
local function EditMark(kit, btn)
    local m = C.editMark
    if not m then
        m = CreateFrame("Frame", nil, UIParent)
        m:SetFrameStrata("MEDIUM")
        m:EnableMouse(false)
        m.tex = m:CreateTexture(nil, "OVERLAY")
        m.tex:SetAllPoints()
        m.tex:SetTexture(kit.media .. "glow_ring")
        m.tex:SetBlendMode("ADD")
        m.tex:SetVertexColor(1, 0.82, 0.3)
        C.editMark = m
    end
    if not btn then m:Hide() return end
    -- (anchored to the button, not a child of it: the button is faint while it's dragged)
    m:SetFrameLevel(btn:GetFrameLevel() + 2)
    m:ClearAllPoints()
    m:SetPoint("CENTER", btn, "CENTER")
    local size = btn:GetWidth() * btn:GetEffectiveScale() / UIParent:GetEffectiveScale() * 1.9
    m:SetSize(size, size)
    m:SetShown(btn:IsShown())
end

-- (v35) What the ghost's label says for a drop target (BarTarget's).
local function TargetText(kit, t)
    if t.zone then
        for _, z in ipairs(kit.cfg.zones or {}) do
            if z.key == t.zone then return z.label or z.key end
        end
    elseif t.bar then
        return Loc["On a bar"]
    elseif t.new then
        return Loc["Floating on its own"]
    elseif t.kit then
        return Loc["Back in its place"]
    end
end

local editDriver = CreateFrame("Frame")
editDriver:Hide()

-- (v38) Where a bar, or a button floating on its own, dragged so its middle
-- would be at (x, y) goes: snapped the way a placed piece is (the screen's
-- middle lines, the kit buttons, the other bars, else its left and top
-- edges to the grid; Shift for free) and kept whole on the screen. hw, hh:
-- its half-size; ex: as Targets'. Also the guide lines to show (or nil).
local function BarSpot(kit, x, y, hw, hh, ex)
    local gx, gy
    if hw then
        x, y, gx, gy = Snap(nil, x, y, hw, hh, ex)
        local sw, sh = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        x = math.max(-sw + hw, math.min(sw - hw, x))
        y = math.max(-sh + hh, math.min(sh - hh, y))
    else
        x, y = kit:ClampBar(x, y)
    end
    local _, snapping = PlaceCfg()
    if not snapping or IsShiftKeyDown() then x, y = Round(x, 1), Round(y, 1) end
    return x, y, gx, gy
end

-- A button was pressed in edit mode: it's a drag once the mouse has moved.
function C.StartEditDrag(kit, btn)
    if C.editDrag or InCombatLockdown() or not kit.editing then return end
    local mx, my = Cursor()
    local key = btn.slot.key
    kit:ZoneDefaults()
    C.editDrag = { kit = kit, kind = "slot", key = key, btn = btn,
        base = kit:BarsWithout(kit.cdb.bars, key), downX = mx, downY = my,
        -- (the kit's zones without it, if it's a slot that lives in one)
        zbase = kit.zoneHome and kit.zoneHome[key] and kit:ZonesWithout(kit:Zones(), key) or nil }
    editDriver:Show()
end

-- A bar's box (or its tab) was pressed: the bar follows the mouse.
function C.StartBarDrag(kit, box)
    if C.editDrag or InCombatLockdown() or not kit.editing or kit.barPreview or not box.bar then return end
    GameTooltip:Hide()
    local mx, my = Cursor()
    C.editDrag = { kit = kit, kind = "bar", bar = box.bar, offX = box.bar.x - mx, offY = box.bar.y - my, downX = mx, downY = my }
    editDriver:Show()
end

-- The drag is over. cancel: leave everything as it was.
function C.StopEditDrag(cancel)
    local d = C.editDrag
    if not d then return end
    C.editDrag = nil
    editDriver:Hide()
    C.Guide(nil, nil)
    if C.editGhost then C.editGhost:Hide() end
    if C.editMark then C.editMark:Hide() end
    local kit = d.kit
    if d.kind == "slot" then
        d.btn.kcDragging = nil
        kit:DropGlow(false)
        local changed = false
        if not cancel and d.moved and kit.barPreview and not InCombatLockdown() then
            kit.cdb.bars = kit.barPreview
            if kit.zonePreview then kit.cdb.zones = kit.zonePreview end
            changed = true
        end
        local had = kit.barPreview ~= nil
        kit.barPreview, kit.zonePreview, kit.zoneHot = nil, nil, nil
        if changed then
            kit:CleanBars()
            kit:CleanZones()
        end
        kit:ApplyZones() -- (the kit's tables as saved, whether or not anything changed)
        if InCombatLockdown() then
            kit.pending = true -- (put right when the fight ends)
            return
        end
        -- (the refresh also ties edit mode's boxes to the bars as they are now)
        if had then kit:Refresh(false) else kit:FadeSlot(d.btn) end
        if changed then
            if kit.Dock and kit.Dock.Layout then kit.Dock.Layout() end -- (an edge strip grows or shrinks)
            kit:SettingsChanged()
        end
    else
        if InCombatLockdown() then kit.pending = true return end
        kit:Refresh(false) -- (its drawers may open the other way from there)
        kit:SettingsChanged()
    end
end

editDriver:SetScript("OnUpdate", function(f)
    local d = C.editDrag
    if not d then f:Hide() return end
    local kit = d.kit
    if InCombatLockdown() or not kit.editing then C.StopEditDrag(true) return end
    local mx, my = Cursor()
    local down = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
    if d.kind == "bar" then
        if not down then C.StopEditDrag(false) return end
        -- (v38: a click on the box doesn't nudge the bar onto the grid)
        if not d.moved and math.abs(mx - d.downX) + math.abs(my - d.downY) < 3 then return end
        d.moved = true
        local _, _, hw, hh = kit:BarExtent(d.bar)
        local x, y, gx, gy = BarSpot(kit, mx + d.offX, my + d.offY, hw, hh, { kit = kit, skip = d.bar })
        C.Guide(gx, gy)
        if x ~= d.bar.x or y ~= d.bar.y then
            d.bar.x, d.bar.y = x, y
            kit:PlaceBars(false)
            kit:PaintEdit()
        end
        return
    end
    if not d.moved then
        if not down then C.StopEditDrag(true) return end
        if math.abs(mx - d.downX) + math.abs(my - d.downY) < 4 then return end -- (a click so far)
        d.moved = true
        GameTooltip:Hide()
        kit:CloseFlyouts()
        local g = EditGhost(kit)
        local size = d.btn:GetWidth() * d.btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
        g:SetSize(size, size)
        g.ring:SetSize(size * 1.6, size * 1.6)
        g.icon:SetTexture(d.btn.icon and d.btn.icon:GetTexture())
        g:SetAlpha(0.9)
        g:Show()
        d.btn.kcDragging = true
    end
    local g = C.editGhost
    if g then
        g:ClearAllPoints()
        g:SetPoint("CENTER", UIParent, "CENTER", mx, my)
    end
    if not down then C.StopEditDrag(false) return end
    -- Show the layout as it would be if it were dropped here. Only a change
    -- of place is a refresh; a button floating on its own just follows.
    local t = kit:BarTarget(d.base, mx, my, d.zbase, d.key)
    -- (v38) A button floating on its own goes on the grid like a bar; the
    -- copy under the mouse still follows the mouse.
    local gx, gy
    if t.new then
        local half = kit:BarButtonSize() / 2
        t.x, t.y, gx, gy = BarSpot(kit, mx, my, half, half, { kit = kit, bars = d.base })
    end
    C.Guide(gx, gy)
    local sig = t.kit and "kit" or t.new and "new" or t.zone and ("zone:" .. t.zone .. ":" .. t.at)
        or (t.bar .. ":" .. t.dir .. ":" .. t.at)
    if sig ~= d.sig then
        d.sig = sig
        kit.barPreview = kit:BarsWith(kit:BarsWithout(d.base), d.key, t)
        kit.zonePreview = t.zone and kit:ZonesWith(d.zbase, d.key, t) or nil
        kit.zoneHot = t.zone
        kit:ApplyZones()
        kit:DropGlow(t.kit)
        kit:Refresh(false)
        -- (v35) The ghost at the size it would be there, saying where that
        -- is, and a ring round the spot it would take.
        if g then SizeGhost(g, d.btn, TargetText(kit, t)) end
        EditMark(kit, d.btn)
    elseif t.new then
        local bar = kit.barPreview and kit.barPreview[#kit.barPreview]
        if bar and (bar.x ~= t.x or bar.y ~= t.y) then
            bar.x, bar.y = t.x, t.y
            kit:PlaceBars(false)
            kit:PaintEdit()
        end
    end
end)

-- The bar at the top of the screen while a layout is being edited.
local function BuildEditBar()
    local bar = OptPanel("Frame", "KitCoreEditBar", UIParent)
    bar:SetSize(500, 116)
    bar:SetPoint("TOP", 0, -20)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "KitCoreEditBar") end -- Esc closes it

    bar.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.title:SetPoint("TOPLEFT", 12, -9)
    local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", bar.title, "BOTTOMLEFT", 0, -5)
    hint:SetWidth(476)
    hint:SetJustifyH("LEFT")
    local layoutHint = Loc["Drag a button into one of the kit's shaded areas to move it there: the one it would land in lights up, and the label under the button says where it'll go. Drop it away from the kit and it floats, always shown; drop another on it to make a bar. Drop it on the kit's icon to put it back. Drag a bar's box to move it."]
        .. " " .. Loc["Bars and buttons on their own snap to the grid, the middle of the screen, the kit buttons and other bars; hold Shift to place them freely."]

    local reset = SmallButton(bar, Loc["Reset to defaults"], 140, function()
        local kit = C.editKit
        if kit then kit:ResetLayout() end
    end)
    reset:SetPoint("BOTTOMLEFT", 12, 10)
    local paintGrid = GridControls(bar, 160) -- (v38: the grid's size and Snap, as when placing)
    local done = SmallButton(bar, Loc["Done"], 70, function() bar:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -12, 10)

    -- (v38) The title and words for what's going on: a layout being edited,
    -- and (Move everything, or a piece's Move) things being placed with it.
    function bar.paint()
        local kit = C.editKit
        if not kit then return end
        local names = {}
        for _, key in ipairs(moverOrder) do
            local m = movers[key]
            if m.placing then names[#names + 1] = m.label or key end
        end
        local text = layoutHint
        if #names == 0 then
            bar.title:SetText((Loc["Editing %s's layout"]):format(kit.name))
        else
            if #names == 1 then
                bar.title:SetText((Loc["Editing %s's layout, placing %s"]):format(kit.name, names[1]))
            else
                bar.title:SetText(Loc["Moving everything"])
            end
            text = Loc["The reminder panel and the kits' timers and bars move by dragging them, snapping the same way."] .. " " .. text
        end
        hint:SetText(text)
        -- (tall enough for the words, whatever the language)
        bar:SetHeight(math.max(116, math.ceil(hint:GetStringHeight() or 0) + 76))
        paintGrid()
    end
    bar:Hide()
    -- (Esc or Done: finished editing. Set only now: a new frame starts shown,
    -- so the Hide above would otherwise end the edit it was built for.)
    bar:SetScript("OnHide", function()
        local kit = C.editKit
        if kit and kit.editing then kit:SetEdit(false) end
    end)
    return bar
end

-- Edit mode on or off. On: the kit opens fully (and stays open), its
-- buttons take drags instead of clicks, and each bar shows its box. Off:
-- everything works again, and the kit closes if it was closed before.
-- (v38) It goes along with placing (Move everything puts the kit it's
-- pressed from into it), and its Done ends that too. quiet: no message when
-- it can't start; handover: off only because another kit's layout is
-- taking over, so whatever's being placed carries on.
function Kit:SetEdit(on, quiet, handover)
    on = on and true or false
    if (self.editing and true or false) == on then return end
    if on then
        if not self.cfg.bars or not self.built then return end
        if InCombatLockdown() then
            if not quiet then self:Print(Loc["The layout can only be edited out of combat."], true) end
            return
        end
        if self.db.shown == false then
            if not quiet then self:Print(Loc["Show the kit first."], true) end
            return
        end
        if self.qkbOpen then
            if not quiet then self:Print(Loc["Close Quick Keybind Mode first."], true) end
            return
        end
        if C.editKit and C.editKit ~= self then C.editKit:SetEdit(false, nil, true) end
        self:CloseFlyouts()
        self.editing = true
        C.editKit = self
        self.editWasOpen = self.open
        if self.open then self:Refresh(false) else self:SetOpen(true) end
        self:ApplyFade()
        self:EditCovers(true)
        C.editBar = C.editBar or BuildEditBar()
        C.editBar:Show()
        C.MoveUI() -- (the grid, under the kits; the bar's words)
        self:PaintEdit()
    else
        C.StopEditDrag(true)
        self.editing = nil
        if C.editKit == self then C.editKit = nil end
        self:EditCovers(false)
        self:HideBarBoxes()
        GameTooltip:Hide()
        if C.editBar and C.editBar:IsShown() then C.editBar:Hide() end
        if handover then C.MoveUI() else C.EndPlacing() end -- (EndPlacing tidies up too)
        if InCombatLockdown() then self.editLeavePending = true return end
        self:EditRestore()
    end
end

-- Edit mode is over: the kit as it was before (closed, if it was closed).
function Kit:EditRestore()
    self.editLeavePending = nil
    if InCombatLockdown() then return end
    local was = self.editWasOpen
    self.editWasOpen = nil
    if was == false and self.open then self:SetOpen(false) else self:Refresh(false) end
    self:ArmOpenFade()
    self:ApplyFade()
end

function Kit:ToggleEdit()
    self:SetEdit(not self.editing)
    if self.optionsUI then self:PaintOptions() end
end

-- The list, gathered into sections: { title, group, items = { item, ... } }.
-- Each sub-heading is an item of its own (kind "sub") that starts a group
-- of the items after it; the window draws each group as a card.
function Kit:CollectOptions()
    local sections, cur, pending, pendingSub, when, group = {}, nil, nil, nil, nil, nil
    local itemWhen, cols
    local function Add(item)
        if pending or not cur then
            cur = { title = pending or self.name, items = {}, group = group }
            sections[#sections + 1] = cur
            pending = nil
        end
        if pendingSub then
            pendingSub.when = when
            pendingSub.section = cur
            cur.items[#cur.items + 1] = pendingSub
            pendingSub = nil
        end
        -- (S.Only: this item alone, inside its group's own "when")
        local only, grp = itemWhen, when
        itemWhen = nil
        if only and grp then
            item.when = function() return grp() and only() end
        else
            item.when = only or grp
        end
        if cols and cols > 1 and item.kind == "check" then item.cols = 2 end
        item.section = cur
        cur.items[#cur.items + 1] = item
    end
    local S = { window = true }
    -- The next setting only shows while fn says true.
    function S.Only(fn) itemWhen = fn end
    function S.Header(text) pending, pendingSub, when, cols = text, nil, nil, nil end
    -- A group inside a section, drawn as a card under its title. when
    -- (optional): a function; the group only shows while it says true
    -- (settings for one style, say). opts.fold: the group starts folded away
    -- under its title, for settings few people need (click the title).
    function S.Subheader(text, w, opts)
        pendingSub, when, cols = { kind = "sub", name = text, fold = opts and opts.fold or nil }, w, nil
    end
    -- A label over the next sections in the window's list down the left.
    function S.Group(text) group = text end
    -- Grid(2): the checkboxes that follow sit two to a line (until Grid(1)
    -- or the next heading).
    function S.Grid(n) cols = n end
    function S.Checkbox(tbl, key, name, tip, default, fn)
        Add({ kind = "check", tbl = tbl, key = key, name = name, tip = tip, default = default, fn = fn })
    end
    function S.Slider(tbl, key, name, tip, default, min, max, step, fmt, fn)
        Add({ kind = "slider", tbl = tbl, key = key, name = name, tip = tip, default = default,
            min = min, max = max, step = step, fmt = fmt, fn = fn })
    end
    -- (Up to four short choices show as a row of buttons, more as a menu.)
    function S.Dropdown(tbl, key, name, tip, default, list, fn)
        Add({ kind = "dropdown", tbl = tbl, key = key, name = name, tip = tip, default = default, list = list, fn = fn })
    end
    -- A choice whose value is read and stored by functions (one choice over
    -- two switches, say). A list entry can carry its own tooltip, for its
    -- button: { value, label, tip, title } (v27, title defaults to the
    -- label). opts.heads (v27): small gold words over each
    -- choice when they show as a row of buttons, like a table's column
    -- heads; rows under it with the same choices line up beneath them.
    function S.Choice(name, tip, list, get, set, fn, opts)
        Add({ kind = "dropdown", name = name, tip = tip, list = list, get = get, set = set, fn = fn,
            heads = opts and opts.heads or nil })
    end
    -- A colour, as a row of coloured squares (v29): one per preset, the one
    -- in use marked, then a Custom... button with your own colour in its
    -- square that opens the game's colour picker (Cancel puts back what you
    -- had). list: { { value, label, { r, g, b } }, ... }; get/set read and
    -- store the value, as S.Choice. opts.custom: the value that means your
    -- own colour, with opts.getRGB() giving it ({ r, g, b }, or nil while
    -- none is picked) and opts.setRGB(r, g, b) storing it (nil clears it).
    -- Without opts.custom, just the presets.
    function S.Colors(name, tip, list, get, set, fn, opts)
        opts = opts or {}
        Add({ kind = "colors", name = name, tip = tip, list = list, get = get, set = set, fn = fn,
            custom = opts.custom, getRGB = opts.getRGB, setRGB = opts.setRGB })
    end
    function S.Button(name, text, tip, fn)
        Add({ kind = "button", name = name, text = text, tip = tip, fn = fn })
    end
    -- A line of small grey words, for the little that has to be read.
    function S.Note(text)
        Add({ kind = "note", name = "", tip = text })
    end
    -- A table of the kit's buttons, a row each, with a tick box per column
    -- (show, pinned, glow...). spec = {
    --   cols = { { key, label, tip }, ... },
    --   rows = {
    --     { group = "Round the orb" },       -- a heading between rows
    --     { label, icon = function, sub = true (indented),
    --       hint = "a line shown when the row is opened",
    --       dim = "show" (the column whose tick, off, greys the row),
    --       cells = { [colKey] = { tbl, key, default, fn, off = function } },
    --       more = { { kind = "check", tbl, key, name, tip, default, fn, when },
    --                { kind = "chips", name, items = { { tbl, key, name, default, fn }, ... } } } },
    --   } }
    -- A cell's off() saying true greys it out and it can't be clicked.
    function S.Table(spec)
        Add({ kind = "table", spec = spec, name = spec.name or "", tip = "" })
    end
    -- A frame the kit draws itself (v30), for what the other rows can't
    -- show: a preview, say. make(parent, w) builds it, w wide, and returns
    -- it with its height set. Its Paint(), if it has one, runs each time the
    -- page is painted (as a setting changes); it can change the frame's
    -- height there, and the page is laid out again after. make runs once
    -- for each page it's on (the search page makes its own), so it must
    -- build a new frame each time. name and tip are what the search box
    -- finds it by; the frame shows its own tooltips. The window's only: a
    -- kit with the game's options page too can check S.window and give
    -- that page plain settings instead.
    function S.Custom(name, tip, make)
        Add({ kind = "custom", name = name or "", tip = tip or "", make = make })
    end
    self:SettingsList(S)
    return sections
end

local function Value(item)
    if item.get then return item.get() end
    local v = item.tbl[item.key]
    if v == nil then v = item.default end
    return v
end

-- A change from the window: store it, run its follow-up, and keep the
-- game's options page in step.
function Kit:OptionChanged(item, v)
    if item.set then
        local ok, err = pcall(item.set, v)
        if not ok then geterrorhandler()(err) end
    else
        item.tbl[item.key] = v
    end
    if item.fn then
        local ok, err = pcall(item.fn, v)
        if not ok then geterrorhandler()(err) end
    end
    if self.OnSettingsChanged then pcall(self.OnSettingsChanged) end
    -- Settings shown only for some choices, and ones that follow others:
    -- paint the page and lay it out again.
    self:PaintOptions()
end

-- The page in view, laid out again (something came or went, or grew).
function Kit:RelayoutOptions()
    local ui = self.optionsUI
    local page = ui and ui.shown
    if not page then return end
    page.Relayout()
    ui.child:SetHeight(page:GetHeight())
    ui.UpdateBar()
end

-- A setting's description, as its tooltip: beside the window, level with
-- the row (v24; it used to sit under every setting).
local function Tip(f, item, anchor)
    f:HookScript("OnEnter", function(self)
        if not (item.tip and item.tip ~= "") then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        local win = anchor and anchor()
        if win then
            GameTooltip:SetPoint("TOP", self, "TOP", 0, 4)
            GameTooltip:SetPoint("LEFT", win, "RIGHT", 4, 0)
        else
            GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0)
        end
        local name = item.name
        if name and name ~= "" then
            GameTooltip:SetText(name, 1, 0.82, 0)
            GameTooltip:AddLine(item.tip, 0.9, 0.9, 0.9, true)
        else
            GameTooltip:SetText(item.tip, 0.9, 0.9, 0.9, 1, true)
        end
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local ROW = {}
local ROW_H = 22      -- a one-line row
local HEADS_H = 14    -- column heads over a row of buttons (S.Choice heads)
local SLIDER_W = 150  -- a slider's track
local CARD_PAD = 12   -- inside a card
local ROW_GAP = 8     -- between rows
local BLOCK_GAP = 12  -- between cards
local COL_GAP = 16    -- between two side-by-side checkboxes

-- A small dark button with a gold edge and gold words.
local function GoldButton(parent, text, h)
    local b = CreateFrame("Button", nil, parent)
    Well(b, 0.55)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetSize(math.max(64, math.floor(b.text:GetStringWidth() + 24)), h or 22)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.15)
    return b
end

-- A label down the left of a row, `room` wide; returns the row's height.
local function Label(row, item, room, x)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", x or 0, 0)
    row.label:SetWidth(math.max(60, room))
    row.label:SetJustifyH("LEFT")
    row.label:SetText(item.name)
    return math.max(ROW_H, math.ceil(row.label:GetStringHeight()) + 6)
end

-- A tick box (16 square, a dark well with the gold edge).
local function TickBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(16, 16)
    Well(box, 0.7)
    box.tick = box:CreateTexture(nil, "OVERLAY")
    box.tick:SetPoint("CENTER", 1, 0)
    box.tick:SetSize(22, 22)
    box.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.tick:SetVertexColor(1, 0.85, 0.4)
    return box
end

function ROW.check(kit, parent, item, w)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(w)
    local box = TickBox(row)
    box:SetPoint("LEFT", 2, 0)
    row:SetHeight(Label(row, item, w - 30, 26))
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", -4, 1)
    hl:SetPoint("BOTTOMRIGHT", 4, -1)
    hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.07)
    Tip(row, item, kit.optAnchor)
    function row.Paint() box.tick:SetShown(Value(item) and true or false) end
    row:SetScript("OnClick", function()
        kit:OptionChanged(item, not Value(item))
        row.Paint()
    end)
    return row
end

function ROW.slider(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    row:EnableMouse(true)
    row:SetHeight(Label(row, item, w - SLIDER_W - 60))
    local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("RIGHT", 0, 0)
    val:SetWidth(44)
    val:SetJustifyH("RIGHT")
    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("RIGHT", val, "LEFT", -8, 0)
    s:SetSize(SLIDER_W, 16)
    s:SetMinMaxValues(item.min, item.max)
    if s.SetValueStep then s:SetValueStep(item.step) end
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(0, 0, 0, 0.8)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetHeight(4)
    fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.75)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    thumb:SetColorTexture(1, 0.85, 0.45, 1)
    s:SetThumbTexture(thumb)
    local function Show(v)
        val:SetText(item.fmt and item.fmt(v) or tostring(v))
        local k = (item.max > item.min) and (v - item.min) / (item.max - item.min) or 0
        fill:SetWidth(math.max(1, k * SLIDER_W))
    end
    local painting
    function row.Paint()
        painting = true
        local v = Value(item)
        s:SetValue(v)
        Show(v)
        painting = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        if item.step and item.step > 0 then
            v = item.min + math.floor((v - item.min) / item.step + 0.5) * item.step
            v = tonumber(("%.4f"):format(v))
        end
        Show(v)
        if painting or v == Value(item) then return end
        kit:OptionChanged(item, v)
    end)
    s:EnableMouseWheel(false)
    Tip(row, item, kit.optAnchor)
    Tip(s, item, kit.optAnchor)
    return row
end

local function OptionLabel(item, v)
    for _, o in ipairs(item.list) do if o[1] == v then return o[2] end end
    return tostring(v)
end

-- Up to four short choices: a row of buttons, the chosen one lit.
local function Segments(kit, row, item, w)
    if #item.list > 4 then return end
    local probe = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local widths, total = {}, 0
    for i, o in ipairs(item.list) do
        probe:SetText(o[2])
        widths[i] = math.floor(probe:GetStringWidth() + 20)
        total = total + widths[i]
    end
    probe:Hide()
    if total > w - 110 then return end
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(total, 22)
    box:SetPoint("RIGHT", 0, 0)
    row.segBox = box
    GoldEdge(box, 0.45)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    local buttons, x = {}, 0
    for i, o in ipairs(item.list) do
        local b = CreateFrame("Button", nil, box)
        b:SetSize(widths[i], 22)
        b:SetPoint("LEFT", x, 0)
        x = x + widths[i]
        b.sel = b:CreateTexture(nil, "ARTWORK")
        b.sel:SetAllPoints()
        b.sel:SetColorTexture(1, 0.82, 0, 0.15)
        if i > 1 then
            local div = b:CreateTexture(nil, "BORDER")
            div:SetPoint("TOPLEFT")
            div:SetPoint("BOTTOMLEFT")
            div:SetWidth(1)
            div:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
        end
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.1)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(o[2])
        b.value = o[1]
        b:SetScript("OnClick", function()
            kit:OptionChanged(item, o[1])
            row.Paint()
        end)
        -- (a choice with its own tooltip, list entry { value, label, tip,
        -- title }, v27: that one over the button instead of the row's)
        Tip(b, o[3] and { name = o[4] or o[2], tip = o[3] } or item, kit.optAnchor)
        buttons[i] = b
        -- (its column head, over it)
        local head = item.heads and item.heads[i]
        if head and head ~= "" then
            local fs = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("BOTTOM", b, "TOP", 0, 3)
            fs:SetText(head)
        end
    end
    function row.Paint()
        local v = Value(item)
        for _, b in ipairs(buttons) do
            local on = b.value == v
            b.sel:SetShown(on)
            if on then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(0.75, 0.72, 0.63) end
        end
    end
    return total
end

function ROW.dropdown(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    row:EnableMouse(true)
    Tip(row, item, kit.optAnchor)
    local segW = Segments(kit, row, item, w)
    if segW then
        local h = Label(row, item, w - segW - 12)
        if item.heads then
            -- Column heads over the buttons: the label and buttons drop
            -- below them.
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "BOTTOMLEFT", 0, h / 2)
            local box = row.segBox
            box:ClearAllPoints()
            box:SetPoint("RIGHT", row, "BOTTOMRIGHT", 0, h / 2)
            h = h + HEADS_H
        end
        row:SetHeight(h)
        return row
    end
    local bw = 180
    row:SetHeight(Label(row, item, w - bw - 12))
    local b = CreateFrame("Button", nil, row)
    b:SetSize(bw, 22)
    b:SetPoint("RIGHT", 0, 0)
    Well(b, 0.7)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetVertexColor(1, 0.85, 0.45)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
    Tip(b, item, kit.optAnchor)
    function row.Paint() text:SetText(OptionLabel(item, Value(item))) end
    b:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, o in ipairs(item.list) do
                    root:CreateRadio(o[2], function() return Value(item) == o[1] end, function()
                        kit:OptionChanged(item, o[1])
                        row.Paint()
                    end, o[1])
                end
            end)
        else
            -- No menus on this build: step to the next choice.
            local cur, i = Value(item), 1
            for n, o in ipairs(item.list) do if o[1] == cur then i = n end end
            local nxt = item.list[i % #item.list + 1]
            kit:OptionChanged(item, nxt[1])
            row.Paint()
        end
    end)
    return row
end

-- A colour (S.Colors, v29): a square per preset, the one in use marked with
-- a gold edge and an x, then Custom... with your own colour in its square.
local SWATCH = 18     -- a colour square
local SWATCH_GAP = 4  -- between squares

-- A square of colour: a dark rim, the colour inside, and (when it's the one
-- in use) a gold edge round it and an x on it.
local function Swatch(parent, size)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(size, size)
    s.edge = s:CreateTexture(nil, "BACKGROUND", nil, -8)
    s.edge:SetPoint("TOPLEFT", -2, 2)
    s.edge:SetPoint("BOTTOMRIGHT", 2, -2)
    s.edge:SetColorTexture(1, 0.82, 0, 1)
    s.edge:Hide()
    local rim = s:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0, 0, 0, 0.9)
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetPoint("TOPLEFT", 2, -2)
    s.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    s.x = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.x:SetPoint("CENTER", 0, 1)
    s.x:SetText("x")
    s.x:Hide()
    return s
end

-- Colour a square (nil: empty, a dark well).
local function SwatchColor(s, rgb)
    s.rgb = rgb
    if rgb then
        s.fill:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    else
        s.fill:SetColorTexture(0.12, 0.1, 0.14, 1)
    end
end

-- Mark a square as the one in use (or not). The x is dark on a light
-- colour and white on a dark one.
local function SwatchChosen(s, on)
    s.edge:SetShown(on)
    s.x:SetShown(on)
    if on then
        local c = s.rgb
        local light = c and (0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]) > 0.55
        if light then s.x:SetTextColor(0.05, 0.05, 0.05) else s.x:SetTextColor(1, 1, 1) end
    end
end

-- Custom...: the game's colour picker on the item's own colour (or, with
-- none picked yet, the colour in use). It's chosen as it opens; Cancel puts
-- back your own colour and what was chosen before.
local function PickCustom(kit, item)
    if not ColorPickerFrame then return end
    local before = Value(item)
    local had = item.getRGB and item.getRGB()
    local start = had
    if not start then
        for _, o in ipairs(item.list) do
            if o[1] == before then start = o[3] end
        end
    end
    start = start or { 1, 1, 1 }
    local function SetRGB(r, g, b)
        if not item.setRGB then return end
        local ok, err = pcall(item.setRGB, r, g, b)
        if not ok then geterrorhandler()(err) end
    end
    -- Your own colour changed: the kit redraws, and so does the window.
    local function Changed()
        if item.fn then
            local ok, err = pcall(item.fn, Value(item))
            if not ok then geterrorhandler()(err) end
        end
        if kit.OnSettingsChanged then pcall(kit.OnSettingsChanged) end
        kit:PaintOptions()
    end
    local function Picked()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        SetRGB(r, g, b)
        if Value(item) ~= item.custom then kit:OptionChanged(item, item.custom) else Changed() end
    end
    local function Cancelled()
        if had then SetRGB(had[1], had[2], had[3]) else SetRGB(nil) end
        if Value(item) ~= before then kit:OptionChanged(item, before) else Changed() end
    end
    if not had then SetRGB(start[1], start[2], start[3]) end
    if before ~= item.custom then kit:OptionChanged(item, item.custom) else Changed() end
    local info = {
        r = start[1], g = start[2], b = start[3], hasOpacity = false,
        swatchFunc = Picked, cancelFunc = Cancelled,
    }
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = Picked, Cancelled, false
        ColorPickerFrame:SetColorRGB(start[1], start[2], start[3])
        ColorPickerFrame:Show()
    end
end

function ROW.colors(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    row:EnableMouse(true)
    Tip(row, item, kit.optAnchor)
    local box = CreateFrame("Frame", nil, row)
    local squares, x = {}, 2
    for i, o in ipairs(item.list) do
        local s = Swatch(box, SWATCH)
        s:SetPoint("LEFT", x, 0)
        x = x + SWATCH + SWATCH_GAP
        SwatchColor(s, o[3])
        s.value = o[1]
        local hl = s:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 2, -2)
        hl:SetPoint("BOTTOMRIGHT", -2, 2)
        hl:SetColorTexture(1, 1, 1, 0.25)
        s:SetScript("OnClick", function()
            kit:OptionChanged(item, o[1])
            row.Paint()
        end)
        Tip(s, { name = o[2], tip = item.tip }, kit.optAnchor)
        squares[i] = s
    end
    local custom
    if item.custom then
        custom = CreateFrame("Button", nil, box)
        Well(custom, 0.55)
        custom.sel = custom:CreateTexture(nil, "ARTWORK")
        custom.sel:SetAllPoints()
        custom.sel:SetColorTexture(1, 0.82, 0, 0.15)
        local hl = custom:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
        custom.chip = Swatch(custom, 14)
        custom.chip:EnableMouse(false)
        custom.chip:SetPoint("LEFT", 6, 0)
        custom.text = custom:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        custom.text:SetPoint("LEFT", custom.chip, "RIGHT", 6, 0)
        custom.text:SetText(Loc["Custom..."])
        custom:SetSize(math.floor(custom.text:GetStringWidth() + 14 + 6 + 6 + 10), 22)
        custom:SetPoint("LEFT", x + 4, 0)
        x = x + 4 + custom:GetWidth()
        custom:SetScript("OnClick", function() PickCustom(kit, item) end)
        Tip(custom, { name = Loc["Custom"], tip = Loc["Pick any colour in the game's colour picker. Cancel puts back what you had."] }, kit.optAnchor)
    else
        x = x - SWATCH_GAP + 2
    end
    box:SetSize(x, 22)
    -- Beside the label, or under it when they don't both fit.
    local h
    if w - x - 12 >= 90 then
        box:SetPoint("RIGHT", 0, 0)
        h = Label(row, item, w - x - 12)
    else
        h = Label(row, item, w)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", 0, -4)
        box:SetPoint("BOTTOMRIGHT", 0, 0)
        h = h + 26
    end
    row:SetHeight(h)
    function row.Paint()
        local v = Value(item)
        for _, s in ipairs(squares) do SwatchChosen(s, s.value == v) end
        if custom then
            local on = v == item.custom
            SwatchColor(custom.chip, item.getRGB and item.getRGB() or nil)
            SwatchChosen(custom.chip, on)
            custom.sel:SetShown(on)
            if on then custom.text:SetTextColor(1, 0.82, 0) else custom.text:SetTextColor(0.75, 0.72, 0.63) end
        end
    end
    return row
end

-- A card's title: gold words. A folding one is a button, with an arrow.
local function FoldKey(item)
    return (item.section and item.section.title or "") .. "/" .. item.name
end

function ROW.sub(kit, parent, item, w)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(w)
    row:SetHeight(18)
    local x = 0
    if item.fold then
        row.arrow = row:CreateTexture(nil, "OVERLAY")
        row.arrow:SetSize(12, 12)
        row.arrow:SetPoint("LEFT", 0, 0)
        row.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        row.arrow:SetVertexColor(1, 0.85, 0.45)
        x = 16
        row:SetScript("OnClick", function()
            local ui = kit.optionsUI
            ui.unfolded[FoldKey(item)] = not ui.unfolded[FoldKey(item)]
            row.Paint()
            kit:RelayoutOptions()
        end)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", -4, 2)
        hl:SetPoint("BOTTOMRIGHT", 4, -2)
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.07)
    else
        row:EnableMouse(false)
    end
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", x, 0)
    text:SetText(item.name)
    function row.Paint()
        if row.arrow then
            local open = kit.optionsUI.unfolded[FoldKey(item)]
            if row.arrow.SetRotation then row.arrow:SetRotation(open and 0 or math.pi / 2) end
        end
    end
    return row
end

function ROW.button(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    row:EnableMouse(true)
    Tip(row, item, kit.optAnchor)
    local b = GoldButton(row, item.text)
    b:SetPoint("RIGHT", 0, 0)
    Tip(b, item, kit.optAnchor)
    b:SetScript("OnClick", function()
        local ok, err = pcall(item.fn)
        if not ok then geterrorhandler()(err) end
        if kit.optionsUI then kit:PaintOptions() end
    end)
    row:SetHeight(Label(row, item, w - b:GetWidth() - 12))
    function row.Paint() end
    return row
end

function ROW.note(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    fs:SetText(item.tip)
    row:SetHeight(math.ceil(fs:GetStringHeight()) + 2)
    function row.Paint() end
    return row
end

-- A kit's own frame (S.Custom, v30). An error in the kit's make or Paint
-- goes to the error handler and leaves the rest of the page working.
function ROW.custom(kit, parent, item, w)
    local ok, row = pcall(item.make, parent, w)
    if not ok or type(row) ~= "table" or not row.SetPoint then
        if not ok then geterrorhandler()(row) end
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(1)
    end
    row:SetParent(parent)
    row:SetWidth(w)
    local paint = row.Paint
    function row.Paint()
        if not paint then return end
        local okP, err = pcall(paint)
        if not okP then geterrorhandler()(err) end
    end
    return row
end

-- The table of a kit's buttons (S.Table): a row each, a tick box per column,
-- and a name to click for the rest (a line about it, a few more choices).
local TCOL = 54
local TROW_H = 26

local function Chips(kit, parent, item, w)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", 0, -5)
    label:SetText(item.name or "")
    local x, y = math.floor(label:GetStringWidth()) + (item.name and 8 or 0), 0
    local chips = {}
    for _, c in ipairs(item.items) do
        local b = CreateFrame("Button", nil, row)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(c.name)
        local cw = math.floor(b.text:GetStringWidth() + 20)
        if x + cw > w and x > 0 then x, y = 0, y + 24 end
        b:SetSize(cw, 20)
        b:SetPoint("TOPLEFT", x, -y)
        x = x + cw + 6
        GoldEdge(b, 0.35)
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints()
        b.sel:SetColorTexture(1, 0.82, 0, 0.14)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.1)
        b:SetScript("OnClick", function()
            kit:OptionChanged(c, not Value(c))
            row.Paint()
        end)
        Tip(b, c, kit.optAnchor)
        b.item = c
        chips[#chips + 1] = b
    end
    row:SetHeight(y + 20)
    function row.Paint()
        for _, b in ipairs(chips) do
            local on = Value(b.item) and true or false
            b.sel:SetShown(on)
            if on then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(0.6, 0.58, 0.5) end
        end
    end
    return row
end

function ROW.table(kit, parent, item, w)
    local spec = item.spec
    local cols = spec.cols
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(w)
    local labelW = w - #cols * TCOL
    for i, c in ipairs(cols) do
        local h = CreateFrame("Frame", nil, row)
        h:SetSize(TCOL, 16)
        h:SetPoint("TOPLEFT", labelW + (i - 1) * TCOL, 0)
        h:EnableMouse(true)
        local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText(c.label)
        Tip(h, { name = c.label, tip = c.tip }, kit.optAnchor)
    end
    local lines = {}
    for _, r in ipairs(spec.rows) do
        if r.group then
            local g = CreateFrame("Frame", nil, row)
            g:SetSize(w, 26)
            local fs = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("BOTTOMLEFT", 2, 6)
            fs:SetText(r.group)
            local line = g:CreateTexture(nil, "BORDER")
            line:SetPoint("BOTTOMLEFT", 0, 1)
            line:SetPoint("BOTTOMRIGHT", 0, 1)
            line:SetHeight(1)
            line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
            g.isGroup = true
            lines[#lines + 1] = g
        else
            local L = CreateFrame("Frame", nil, row)
            L:SetWidth(w)
            L.r = r
            local under = L:CreateTexture(nil, "BORDER")
            under:SetPoint("BOTTOMLEFT")
            under:SetPoint("BOTTOMRIGHT")
            under:SetHeight(1)
            under:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
            L.openBg = L:CreateTexture(nil, "BACKGROUND")
            L.openBg:SetAllPoints()
            L.openBg:SetColorTexture(1, 0.82, 0, 0.035)
            local more = (r.hint and r.hint ~= "") or (r.more and #r.more > 0)
            local nb = CreateFrame("Button", nil, L)
            nb:SetPoint("TOPLEFT", 0, 0)
            nb:SetSize(labelW - 4, TROW_H)
            local x = r.sub and 18 or 0
            if more then
                L.arrow = nb:CreateTexture(nil, "OVERLAY")
                L.arrow:SetSize(10, 10)
                L.arrow:SetPoint("LEFT", x + 1, 0)
                L.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
                L.arrow:SetVertexColor(0.75, 0.65, 0.4)
                local hl = nb:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.07)
            end
            L.icon = nb:CreateTexture(nil, "ARTWORK")
            L.icon:SetSize(18, 18)
            L.icon:SetPoint("LEFT", x + 14, 0)
            L.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (square, the icon's own border trimmed)
            L.label = nb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            L.label:SetPoint("LEFT", L.icon, "RIGHT", 7, 0)
            L.label:SetPoint("RIGHT", nb, "RIGHT", -2, 0)
            L.label:SetJustifyH("LEFT")
            L.label:SetWordWrap(false)
            L.label:SetText(r.label)
            nb:SetScript("OnClick", function()
                if not more then return end
                L.open = not L.open
                row.Paint()
                kit:RelayoutOptions()
            end)
            L.cells = {}
            for i, c in ipairs(cols) do
                local cell = r.cells and r.cells[c.key]
                local cx = labelW + (i - 0.5) * TCOL
                if cell then
                    cell.name = cell.name or (r.label .. ": " .. c.label)
                    cell.tip = cell.tip or c.tip
                    local b = CreateFrame("Button", nil, L)
                    b:SetSize(TCOL - 8, TROW_H - 4)
                    b:SetPoint("CENTER", L, "TOPLEFT", cx, -TROW_H / 2)
                    b.box = TickBox(b)
                    b.box:SetPoint("CENTER")
                    local hl = b:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
                    b.cell = cell
                    Tip(b, cell, kit.optAnchor)
                    b:SetScript("OnClick", function()
                        if b.off then return end
                        kit:OptionChanged(cell, not Value(cell))
                        row.Paint()
                    end)
                    L.cells[#L.cells + 1] = b
                else
                    local dash = L:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    dash:SetPoint("CENTER", L, "TOPLEFT", cx, -TROW_H / 2)
                    dash:SetText("-")
                    dash:SetAlpha(0.5)
                end
            end
            -- What opens under the row.
            local det = CreateFrame("Frame", nil, L)
            det:SetPoint("TOPLEFT", 32, -(TROW_H + 2))
            local dw = w - 40
            det:SetWidth(dw)
            det.parts = {}
            if r.hint and r.hint ~= "" then
                det.parts[#det.parts + 1] = ROW.note(kit, det, { tip = r.hint }, dw)
            end
            for _, m in ipairs(r.more or {}) do
                local p
                if m.kind == "chips" then
                    p = Chips(kit, det, m, dw)
                else
                    p = ROW.check(kit, det, m, dw)
                end
                p.item = m
                det.parts[#det.parts + 1] = p
            end
            function det.Layout()
                local y = 0
                for _, p in ipairs(det.parts) do
                    local show = true
                    if p.item and p.item.when then
                        local ok, s = pcall(p.item.when)
                        show = ok and s
                    end
                    if show then
                        p:ClearAllPoints()
                        p:SetPoint("TOPLEFT", 0, -y)
                        p:Show()
                        y = y + p:GetHeight() + 6
                    else
                        p:Hide()
                    end
                end
                det:SetHeight(math.max(1, y))
            end
            L.det = det
            lines[#lines + 1] = L
        end
    end
    function row.Layout()
        local y = 18
        for _, L in ipairs(lines) do
            L:ClearAllPoints()
            L:SetPoint("TOPLEFT", 0, -y)
            if L.isGroup then
                y = y + L:GetHeight()
            else
                local h = TROW_H
                if L.open then
                    L.det.Layout()
                    L.det:Show()
                    h = TROW_H + 2 + L.det:GetHeight() + 6
                else
                    L.det:Hide()
                end
                L:SetHeight(h)
                y = y + h
            end
        end
        row:SetHeight(y)
    end
    function row.Paint()
        for _, L in ipairs(lines) do
            if not L.isGroup then
                local r = L.r
                local tex
                if r.icon then
                    local ok, t = pcall(r.icon)
                    tex = ok and t or nil
                end
                L.icon:SetTexture(tex or 134400)
                local dim = r.dim and r.cells and r.cells[r.dim] and not Value(r.cells[r.dim])
                L.label:SetAlpha(dim and 0.45 or 1)
                L.icon:SetAlpha(dim and 0.45 or 1)
                for _, b in ipairs(L.cells) do
                    b.box.tick:SetShown(Value(b.cell) and true or false)
                    local off = false
                    if b.cell.off then
                        local ok, o = pcall(b.cell.off)
                        off = ok and o and true or false
                    end
                    b.off = off
                    b:SetAlpha(off and 0.3 or 1)
                end
                if L.arrow and L.arrow.SetRotation then L.arrow:SetRotation(L.open and 0 or math.pi / 2) end
                L.openBg:SetShown(L.open and true or false)
                for _, p in ipairs(L.det.parts) do p.Paint() end
            end
        end
        row.Layout()
    end
    row.Layout()
    return row
end

-- A page: a title, then its settings in cards (one per sub-heading; the
-- settings before the first sub-heading sit on the page itself). Rows are
-- made the first time they're needed and kept.
local function MakePage(kit, ui)
    local page = CreateFrame("Frame", nil, ui.child)
    page:SetPoint("TOPLEFT")
    local w = ui.child:GetWidth()
    page:SetWidth(w)
    page.head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.head:SetPoint("TOPLEFT", 0, 0)
    local line = page:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", 0, -26)
    line:SetPoint("TOPRIGHT", 0, -26)
    line:SetHeight(1)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    local rowFor, cardFor = {}, {}
    page.rows, page.blocks = {}, {}

    local function RowFor(item, inner)
        local row = rowFor[item]
        if not row then
            local make = ROW[item.kind]
            if not make then return end
            local rw = inner
            if item.cols then rw = math.floor((inner - COL_GAP) / 2) end
            row = make(kit, page, item, rw)
            row.item = item
            rowFor[item] = row
        end
        return row
    end
    local function CardFor(sub)
        local card = cardFor[sub]
        if not card then
            card = CreateFrame("Frame", nil, page)
            card:SetFrameLevel(page:GetFrameLevel())
            local bg = card:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.025)
            GoldEdge(card, 0.2)
            cardFor[sub] = card
        end
        return card
    end

    -- The page's settings (in order, sub-headings included).
    function page.SetItems(items)
        for _, row in pairs(rowFor) do
            row:Hide()
            row.atX, row.atY = nil, nil
        end
        for _, card in pairs(cardFor) do card:Hide() end
        page.rows, page.blocks = {}, {}
        local b
        for _, item in ipairs(items) do
            if item.kind == "sub" then
                b = { sub = item, items = {} }
                page.blocks[#page.blocks + 1] = b
            else
                if not b then
                    b = { items = {} }
                    page.blocks[#page.blocks + 1] = b
                end
                b.items[#b.items + 1] = item
            end
        end
        for _, blk in ipairs(page.blocks) do
            local inner = blk.sub and (w - 2 * CARD_PAD) or w
            if blk.sub then
                blk.subRow = RowFor(blk.sub, inner)
                blk.card = CardFor(blk.sub)
                page.rows[#page.rows + 1] = blk.subRow
            end
            blk.rows = {}
            for _, item in ipairs(blk.items) do
                local row = RowFor(item, inner)
                if row then
                    blk.rows[#blk.rows + 1] = row
                    page.rows[#page.rows + 1] = row
                end
            end
        end
    end

    local function Shown(item)
        if not item.when then return true end
        local ok, show = pcall(item.when)
        return ok and show and true or false
    end

    -- Stack the cards and their rows, leaving out what's hidden or folded.
    -- (Rows already in place stay shown and stay put: hiding or re-anchoring
    -- one would drop a slider being dragged, since every change lays the page
    -- out again.)
    local function Put(row, x, y)
        row.keep = true
        if row.atX ~= x or row.atY ~= y or not row:IsShown() then
            row.atX, row.atY = x, y
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x, -y)
            row:Show()
        end
    end
    function page.Relayout()
        for _, row in ipairs(page.rows) do row.keep = nil end
        local y = 38
        for _, blk in ipairs(page.blocks) do
            if blk.card then blk.card:Hide() end
            local vis = {}
            if not blk.sub or Shown(blk.sub) then
                for _, row in ipairs(blk.rows) do
                    if Shown(row.item) then vis[#vis + 1] = row end
                end
            end
            if #vis > 0 then
                local folded = blk.sub and blk.sub.fold and not ui.unfolded[FoldKey(blk.sub)]
                local x0 = blk.sub and CARD_PAD or 0
                local top = y
                local yy = y + (blk.sub and CARD_PAD or 0)
                if blk.sub then
                    Put(blk.subRow, x0, yy)
                    yy = yy + blk.subRow:GetHeight() + (folded and 0 or ROW_GAP)
                end
                if not folded then
                    local i = 1
                    while i <= #vis do
                        local row, nxt = vis[i], vis[i + 1]
                        Put(row, x0, yy)
                        local h = row:GetHeight()
                        if row.item.cols and nxt and nxt.item.cols then
                            Put(nxt, x0 + row:GetWidth() + COL_GAP, yy)
                            h = math.max(h, nxt:GetHeight())
                            i = i + 2
                        else
                            i = i + 1
                        end
                        yy = yy + h + ROW_GAP
                    end
                    yy = yy - ROW_GAP
                end
                if blk.sub then
                    blk.card:ClearAllPoints()
                    blk.card:SetPoint("TOPLEFT", 0, -top)
                    blk.card:SetSize(w, yy - top + CARD_PAD)
                    blk.card:Show()
                    y = yy + CARD_PAD + BLOCK_GAP
                else
                    y = yy + BLOCK_GAP
                end
            end
        end
        for _, row in ipairs(page.rows) do
            if not row.keep and row:IsShown() then row:Hide() end
        end
        page:SetHeight(y)
    end

    page:Hide()
    return page
end

local function Painted(kit, page)
    for _, row in ipairs(page.rows) do if row.Paint then row.Paint() end end
end

local function Present(kit, page)
    local ui = kit.optionsUI
    if ui.shown and ui.shown ~= page then ui.shown:Hide() end
    ui.shown = page
    Painted(kit, page)
    page.Relayout()
    page:Show()
    ui.child:SetHeight(page:GetHeight())
    ui.scroll:SetVerticalScroll(0)
    ui.UpdateBar()
end

local function LightNav(ui, index)
    for i, nav in ipairs(ui.nav) do
        local on = i == index
        nav.text:SetFontObject(on and "GameFontNormal" or "GameFontHighlightSmall")
        nav.bar:SetShown(on)
        nav.sel:SetShown(on)
    end
end

local function ShowPage(kit, index)
    local ui = kit.optionsUI
    index = math.max(1, math.min(index or 1, #ui.sections))
    ui.current = index
    if ui.search and ui.search:GetText() ~= "" then
        ui.quiet = true
        ui.search:SetText("")
        ui.quiet = nil
    end
    LightNav(ui, index)
    local page = ui.pages[index]
    if not page then
        local sec = ui.sections[index]
        page = MakePage(kit, ui)
        page.head:SetText(sec.title)
        page.SetItems(sec.items)
        ui.pages[index] = page
    end
    Present(kit, page)
end

-- Typing in the search box: every setting whose name or description has
-- the words in it, under the name of the page it's on.
local function Matches(item, q)
    if item.kind == "sub" or item.kind == "note" then return false end
    local text = ((item.name or "") .. " " .. (item.tip or "")):lower()
    if text:find(q, 1, true) then return true end
    if item.kind == "table" then
        for _, c in ipairs(item.spec.cols) do
            if ((c.label or "") .. " " .. (c.tip or "")):lower():find(q, 1, true) then return true end
        end
        for _, r in ipairs(item.spec.rows) do
            if ((r.label or "") .. " " .. (r.hint or "")):lower():find(q, 1, true) then return true end
        end
    end
    return false
end

local function ShowSearch(kit, q)
    local ui = kit.optionsUI
    ui.secSub = ui.secSub or {}
    local list = {}
    for _, sec in ipairs(ui.sections) do
        local first = true
        for _, item in ipairs(sec.items) do
            if Matches(item, q) then
                if first then
                    first = false
                    ui.secSub[sec] = ui.secSub[sec] or { kind = "sub", name = sec.title, section = { title = "?search" } }
                    list[#list + 1] = ui.secSub[sec]
                end
                list[#list + 1] = item
            end
        end
    end
    if #list == 0 then
        ui.noMatch = ui.noMatch or { kind = "note", name = "", tip = Loc["No setting matches that. Try another word."] }
        list[1] = ui.noMatch
    end
    ui.results = ui.results or MakePage(kit, ui)
    ui.results.head:SetText((Loc["Settings with \"%s\""]):format(q))
    ui.results.SetItems(list)
    LightNav(ui, 0)
    Present(kit, ui.results)
end

function Kit:PaintOptions()
    local ui = self.optionsUI
    if not (ui and ui.shown) then return end
    if ui.headerArt then pcall(ui.headerArt) end -- (the center icon may have changed)
    Painted(self, ui.shown)
    self:RelayoutOptions()
end

function Kit:BuildOptions()
    local ui = { sections = self:CollectOptions(), pages = {}, nav = {}, unfolded = {} }
    local name = self.prefix .. "Options"
    local f = OptPanel("Frame", name, UIParent)
    f:SetSize(OPT.w, OPT.h)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, name) end -- Esc closes it
    -- (descriptions show beside the window, level with their setting)
    self.optAnchor = function() return f end

    -- Header: the kit's art, its name, a search box and a close button, over
    -- a faint gold line.
    local art = f:CreateTexture(nil, "ARTWORK")
    art:SetSize(26, 26)
    art:SetPoint("TOPLEFT", OPT.pad - 2, -8)
    -- The kit's own look: its minimap art, or else the icon in the middle of
    -- the kit as it is now (its center icon setting), or the minimap icon.
    local function HeaderArt()
        local tex = self.cfg.minimapArt and (type(self.cfg.minimapArt) == "function" and self.cfg.minimapArt(self) or self.cfg.minimapArt)
        if tex then
            art:SetTexture(tex, nil, nil, "LINEAR")
            art:SetTexCoord(0, 1, 0, 1)
        else
            local icon = self.kit and self.kit.icon
            tex = icon and icon:GetTexture()
            if tex then
                art:SetTexture(tex)
                art:SetTexCoord(icon:GetTexCoord())
            else
                tex = self.cfg.minimapIcon and (type(self.cfg.minimapIcon) == "function" and self.cfg.minimapIcon(self) or self.cfg.minimapIcon)
                art:SetTexture(tex or 134400)
                art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
        art:Show()
    end
    pcall(HeaderArt)
    ui.headerArt = HeaderArt
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", art, "RIGHT", 8, 0)
    title:SetText((Loc["%s settings"]):format(self.name))
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)
    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetPoint("TOPLEFT", OPT.pad, -OPT.head)
    sep:SetPoint("TOPRIGHT", -OPT.pad, -OPT.head)
    sep:SetHeight(1)
    sep:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)

    local sb = CreateFrame("EditBox", nil, f)
    sb:SetSize(160, 20)
    sb:SetPoint("RIGHT", close, "LEFT", -6, 0)
    sb:SetAutoFocus(false)
    sb:SetFontObject("GameFontHighlightSmall")
    sb:SetTextInsets(20, 6, 0, 0)
    sb:SetMaxLetters(40)
    Well(sb, 0.6)
    local glass = sb:CreateTexture(nil, "OVERLAY")
    glass:SetSize(12, 12)
    glass:SetPoint("LEFT", 5, 0)
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetVertexColor(0.75, 0.7, 0.55)
    local hint = sb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 20, 0)
    hint:SetText(Loc["Find a setting"])
    local function Hint() hint:SetShown(sb:GetText() == "" and not sb:HasFocus()) end
    sb:SetScript("OnEditFocusGained", Hint)
    sb:SetScript("OnEditFocusLost", Hint)
    sb:SetScript("OnEscapePressed", function(e)
        e:SetText("")
        e:ClearFocus()
    end)
    sb:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
    sb:SetScript("OnTextChanged", function(e)
        Hint()
        if ui.quiet then return end
        local q = (e:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if #q >= 2 then
            ShowSearch(self, q)
        elseif ui.shown == ui.results then
            ShowPage(self, ui.current)
        end
    end)
    ui.search = sb

    -- Sections down the left, with a faint gold line beside them.
    -- Grouped under small grey labels (Kit, the kit's name, and any groups
    -- the kit names).
    local navY, lastGroup = OPT.head + 8, nil
    for i, sec in ipairs(ui.sections) do
        if sec.group and sec.group ~= lastGroup then
            lastGroup = sec.group
            local g = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            g:SetPoint("TOPLEFT", OPT.pad + 2, -(navY + (i > 1 and 6 or 2)))
            g:SetText(sec.group:upper())
            navY = navY + (i > 1 and 22 or 18)
        end
        local b = CreateFrame("Button", nil, f)
        b:SetSize(OPT.nav - OPT.pad - 6, 22)
        b:SetPoint("TOPLEFT", OPT.pad, -navY)
        navY = navY + 23
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints()
        b.sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.1)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("TOPLEFT")
        b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(2)
        b.bar:SetColorTexture(1, 0.85, 0.45, 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.06)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 10, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b.text:SetText(sec.title)
        b:SetScript("OnClick", function() ShowPage(self, i) end)
        ui.nav[i] = b
    end
    -- Move everything and Key bindings, at the foot of the list.
    local move = CreateFrame("Button", nil, f)
    move:SetSize(OPT.nav - OPT.pad - 6, 20)
    move.text = move:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    move.text:SetPoint("LEFT", 10, 0)
    move.text:SetText(Loc["Move everything"])
    local mhl = move:CreateTexture(nil, "HIGHLIGHT")
    mhl:SetAllPoints()
    mhl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.06)
    move:SetScript("OnClick", function() C.MoveAll(self) end)
    Tip(move, { name = Loc["Move everything"], tip = Loc["The reminder panel and every timer and bar in use, shown where they sit on a grid so you can drag them all at once. Done (or Esc) when you're finished."]
        .. (self.cfg.bars and (" " .. Loc["The kit's own buttons and bars too, as in Edit layout."]) or "") .. (self.cfg.slash and (" " .. (Loc["Also %s move."]):format(self.cfg.slash[1])) or "") }, self.optAnchor)
    local keys = CreateFrame("Button", nil, f)
    keys:SetSize(OPT.nav - OPT.pad - 6, 20)
    keys:SetPoint("BOTTOMLEFT", OPT.pad, OPT.pad)
    keys.text = keys:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keys.text:SetPoint("LEFT", 10, 0)
    keys.text:SetText(Loc["Key bindings"])
    local khl = keys:CreateTexture(nil, "HIGHLIGHT")
    khl:SetAllPoints()
    khl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.06)
    keys:SetScript("OnClick", function() self:OpenKeyBindings() end)
    move:SetPoint("BOTTOMLEFT", keys, "TOPLEFT", 0, 2)
    local kline = f:CreateTexture(nil, "BORDER")
    kline:SetPoint("BOTTOMLEFT", move, "TOPLEFT", 0, 4)
    kline:SetPoint("BOTTOMRIGHT", move, "TOPRIGHT", 0, 4)
    kline:SetHeight(1)
    kline:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.18)

    local vline = f:CreateTexture(nil, "BORDER")
    vline:SetPoint("TOPLEFT", OPT.nav, -(OPT.head + 8))
    vline:SetPoint("BOTTOMLEFT", OPT.nav, OPT.pad)
    vline:SetWidth(1)
    vline:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.2)

    -- The chosen section's settings, scrolling with the mouse wheel.
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", OPT.nav + 18, -(OPT.head + 14))
    scroll:SetPoint("BOTTOMRIGHT", -(OPT.pad + 14), OPT.pad)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(OPT.w - OPT.nav - 18 - OPT.pad - 14, 10)
    scroll:SetScrollChild(child)
    -- A slim gold bar showing where you are, when there's more to see.
    -- Drag it to scroll, or click the track beside it to jump there.
    local function MaxScroll()
        return math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
    end
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 0, 0)
    track:SetWidth(14)
    track:EnableMouse(true)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(14)
    thumb:EnableMouse(true)
    thumb:SetFrameLevel(track:GetFrameLevel() + 1)
    local bar = thumb:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPRIGHT", thumb, "TOPRIGHT", -2, 0)
    bar:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 0)
    bar:SetWidth(3)
    bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
    local function Lit(on)
        bar:SetWidth(on and 5 or 3)
        bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.95 or 0.6)
    end
    local function UpdateBar()
        local view, full = scroll:GetHeight() or 0, child:GetHeight() or 0
        if full <= view + 1 then
            if scroll:GetVerticalScroll() ~= 0 then scroll:SetVerticalScroll(0) end
            track:Hide()
            return
        end
        -- A page that got shorter can leave us scrolled past its end.
        if (scroll:GetVerticalScroll() or 0) > full - view then scroll:SetVerticalScroll(full - view) end
        local h = math.max(20, view * view / full)
        local at = (scroll:GetVerticalScroll() or 0) / (full - view)
        thumb:ClearAllPoints()
        thumb:SetHeight(h)
        thumb:SetPoint("TOP", track, "TOP", 0, -at * (view - h))
        track:Show()
    end
    local function SetScroll(v)
        scroll:SetVerticalScroll(math.max(0, math.min(MaxScroll(), v)))
        UpdateBar()
    end
    -- Cursor height in the track's own units, so UI scale doesn't matter.
    local function CursorY()
        local _, y = GetCursorPosition()
        return y / track:GetEffectiveScale()
    end
    thumb:SetScript("OnMouseDown", function(t, button)
        if button ~= "LeftButton" then return end
        t.fromY, t.fromV = CursorY(), scroll:GetVerticalScroll() or 0
        t:SetScript("OnUpdate", function(t2)
            local view = scroll:GetHeight() or 0
            local room = view - (t2:GetHeight() or 0)
            if room <= 0 then return end
            -- Cursor moving down the screen scrolls the page down.
            SetScroll(t2.fromV + (t2.fromY - CursorY()) * MaxScroll() / room)
        end)
        Lit(true)
    end)
    thumb:SetScript("OnMouseUp", function(t)
        t:SetScript("OnUpdate", nil)
        if not t:IsMouseOver() then Lit(false) end
    end)
    thumb:SetScript("OnHide", function(t)
        t:SetScript("OnUpdate", nil)
        Lit(false)
    end)
    thumb:SetScript("OnEnter", function() Lit(true) end)
    thumb:SetScript("OnLeave", function(t)
        if not t:GetScript("OnUpdate") then Lit(false) end
    end)
    -- Clicking the track centres the thumb on the click, then you can keep dragging.
    track:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local top = track:GetTop() or 0
        local view = scroll:GetHeight() or 0
        local h = thumb:GetHeight() or 0
        local room = view - h
        if room <= 0 then return end
        local frac = (top - CursorY() - h / 2) / room
        SetScroll(frac * MaxScroll())
        thumb:GetScript("OnMouseDown")(thumb, "LeftButton")
    end)
    track:SetScript("OnMouseUp", function()
        thumb:GetScript("OnMouseUp")(thumb)
    end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        SetScroll((scroll:GetVerticalScroll() or 0) - delta * 48)
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        SetScroll((sf:GetVerticalScroll() or 0) - delta * 48)
    end)
    ui.scroll, ui.child, ui.UpdateBar = scroll, child, UpdateBar
    ui.frame = f
    f:SetScript("OnShow", function()
        pcall(HeaderArt)
        self:PaintOptions()
    end)
    self.optionsUI = ui
    ShowPage(self, 1)
end

-- Open the window (built the first time), at a section if one's named.
function Kit:OpenOptions(section)
    if not self.optionsUI then
        local ok, err = pcall(self.BuildOptions, self)
        if not ok then
            self.optionsUI = nil
            geterrorhandler()(err)
            return false
        end
    end
    local ui = self.optionsUI
    if section then
        for i, sec in ipairs(ui.sections) do
            if sec.title:lower():find(section:lower(), 1, true) then ShowPage(self, i) break end
        end
    end
    if ui.frame:IsShown() and not section then ui.frame:Hide() else ui.frame:Show() end
    return true
end

-- The kit's entry in Esc > Options > AddOns for a kit with its own window:
-- one button, which closes the game's options and opens the kit's window.
function Kit:BuildSettingsLink()
    local category, layout = Settings.RegisterVerticalLayoutCategory(self.name)
    local function Open()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
        local ui = self.optionsUI
        if not (ui and ui.frame and ui.frame:IsShown()) then self:OpenOptions() end
    end
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer((Loc["%s settings"]):format(self.name), Loc["Open"], Open,
            (Loc["The kit's settings are in its own window. Also from the minimap button, the kit's right-click menu or %s."]):format(self.cfg.slash and self.cfg.slash[1] or Loc["its slash command"]), true))
    end
    Settings.RegisterAddOnCategory(category)
end

function Kit:SetupSettings()
    -- A kit with its own window keeps its settings there only (v17): its
    -- entry in Esc > Options > AddOns is just a button that opens the window.
    if self.cfg.optionsWindow then
        if Settings and Settings.RegisterVerticalLayoutCategory then
            pcall(self.BuildSettingsLink, self)
        end
        return
    end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local ok, err = pcall(self.BuildSettings, self)
    if not ok then
        self.openSettings = nil
        self:Print((Loc["Settings panel failed to load (%s). %s help lists the slash commands."]):format(tostring(err), (self.cfg.slash and self.cfg.slash[1] or "")), true)
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

-- Anything printed while a slash command runs is its answer, so it shows
-- even with "Chat messages" off.
function Kit:Slash(msg)
    self.inSlash = true
    local ok, err = pcall(self.RunSlash, self, msg)
    self.inSlash = nil
    if not ok then error(err, 0) end
end

function Kit:RunSlash(msg)
    local cfg = self.cfg
    local slash = cfg.slash and cfg.slash[1] or ""
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cfg.Slash and cfg.Slash(self, cmd, rest) then return end
    if cmd == "" or cmd == "options" or cmd == "settings" then
        self:OpenSettings()
    elseif cmd == "help" then
        self:Print((Loc["%s - settings"]):format(slash) .. "   " .. slash .. " lock | unlock | show | hide | reset")
        self:Print((Loc["%s minimap - show or hide the minimap button"]):format(slash))
        self:Print((Loc["%s face up | down | left | right - which way the layout points"]):format(slash))
        self:Print((Loc["%s move - move everything: the reminder panel and the kits' timers and bars, all at once"]):format(slash))
        self:Print((Loc["%s panel - move the reminder panel (shared by every kit)"]):format(slash))
        if cfg.bars then self:Print((Loc["%s layout - drag buttons off the kit onto bars"]):format(slash) .. "   " .. slash .. " layout reset") end
        if self.Dock and not cfg.edgesOnly then self:Print((Loc["%s dock - dock every kit on the pin"]):format(slash) .. "   " .. slash .. " flip") end
        for _, line in ipairs(cfg.helpLines or {}) do self:Print(line) end
    elseif InCombatLockdown() then
        self:Print(Loc["That can only change out of combat."])
    elseif cmd == "lock" or cmd == "unlock" then
        self.db.locked = (cmd == "lock")
        self:Print(self.db.locked and Loc["Locked."] or Loc["Unlocked. Drag the kit to move it."])
        self:SettingsChanged()
    elseif cmd == "show" or cmd == "hide" then
        self:SetShownKit(cmd == "show")
    elseif cmd == "dock" and self.Dock and not cfg.edgesOnly then
        if self.Dock.Active() then
            self.Dock.DockAll(self.key)
            self:Print(Loc["Kits docked together on the pin."])
        else
            self:Print(Loc["Docking needs another kit installed."])
        end
    elseif cmd == "face" then
        local f = (rest or ""):lower():match("^(%a+)")
        if f and FACE[f] then
            self:SetFacing(f)
        else
            self:Print((Loc["%s face up | down | left | right   (now %s)"]):format(slash, self.db.facing or "up"))
        end
    elseif cmd == "panel" then
        C.TogglePanelUnlocked(self)
    elseif cmd == "move" then
        C.MoveAll(self)
    elseif (cmd == "layout" or cmd == "bars") and cfg.bars then
        if (rest or ""):lower():match("^reset") then self:ResetLayout() else self:ToggleEdit() end
    elseif cmd == "flip" and self.Dock and not cfg.edgesOnly then
        self.Dock.Flip()
    elseif cmd == "reset" then
        local d = cfg.defaults and cfg.defaults.point or C.BASE_DEFAULTS.point
        self.db.point = { d[1], d[2], d[3], d[4], "ui" } -- (starting spots are in screen units)
        if self.Dock and self.Dock.Undock then self.Dock.Undock(self.key) end
        self:ApplyPosition()
        self:Print(Loc["Kit moved back to its starting spot."])
    elseif cmd == "radialdebug" and self.radial then
        self:RadialDebugToggle()
    elseif cmd == "minimap" then
        self.db.minimapButton = not self.db.minimapButton
        self:ApplyMinimap()
        self:SettingsChanged()
        self:Print(self.db.minimapButton and Loc["Minimap button shown."] or (Loc["Minimap button hidden. %s minimap brings it back."]):format(slash))
    else
        self:Print((Loc["Unknown command. %s help lists them."]):format(slash))
    end
end

---------------------------------------------------------------------------
-- The radial, for controllers (v39)
--
-- With cfg.radial, a kit can be used from a controller as a ring round the
-- middle of the screen instead of opening and closing it. Its binding
-- ("CLICK <prefix>Radial:LeftButton", or /click <prefix>Radial in a macro
-- on a gamepad bar) brings the ring up; tilting a stick points at a button;
-- letting go of the binding (or A) uses it. Tapping the binding leaves the
-- ring up until a button is used, B closes it, or the binding is pressed
-- again with the stick centred.
--
-- The kit's three parts are three rings:
--   main    the kit's ring (zone "ring", or cfg.ring[1]), and, when the kit
--           has a row under its line, a "Below the line" button at the
--           bottom that opens it
--   inner   the kit's small buttons (a zone with small, or the small
--           slots): X with the stick centred opens it, so a button that
--           acts at once (Demonic Sacrifice) is never one flick away
--   below   the row under the line, with the way back to the main ring at
--           the top
-- A slot with a drawer opens it as a ring of its own with X (the
-- right-click of a mouse): the drawer opens with the slot's current
-- choice under the stick, and a choice used there becomes the slot's, as
-- a click in the drawer does. Y does a slot's "alternate" (slot.radialAlt,
-- below), say Fel Domination before a summon. B goes back a ring, and
-- closes the main one.
--
-- Everything that decides what's used is secure, so all of it works in
-- combat: the header's snippets read the stick with GetGamePadState()
-- and "/click" the slot (or drawer choice) it points at, through the
-- button that was pressed. What's in each ring is worked out out of combat,
-- on every refresh, and handed to the header as attributes. The ring you
-- see is drawn by ordinary code from the same lists (and the stick, read
-- the same way), so it can update in combat too.
--
-- While the ring is up, A, B, X and Y belong to it (override bindings on
-- the header, cleared as it closes). The stick it reads is held off the
-- camera (cfg setting), the way ConsolePort's rings do it: the camera's
-- stick event for that frame is caught by a frame that stops it.
--
-- slot.radialAlt = { label = "...", ready = function(kit) end,
--                    macro = function(kit, btn, choice, target) end }
--     Y on this slot (choice nil) or on one of its drawer's choices: macro
--     returns the macro text to run ("/cast X\n/click " .. target, target
--     being the button's name) or nil for none; ready (optional) says
--     whether to offer it right now (the prompt only: the macro is set out
--     of combat).
---------------------------------------------------------------------------

local RADIAL = {
    DEAD = 0.35,                     -- how far the stick leans before it points at anything (0..1)
    KEYS = { use = "PAD1", back = "PAD2", open = "PAD3", alt = "PAD4" },
    RADIUS = 175, ICON = 46, SMALL = 34,
    INVERT_Y = 1,                    -- the stick's y: 1 = up is positive
    RAW = { "Left", "Right", "Gyro" }, -- the game's stick events, in the order they come each frame
    VIRT = { Left = "Movement", Right = "Camera", Gyro = "Look" },
}

-- Header snippets (run with owner:RunAttribute from the buttons' snippets).
-- CUR is the ring that's up (nil: none), ROT how far a drawer is turned
-- (degrees), so its current choice sits where its slot did.
RADIAL.PICK = [[
    if not CUR then return end
    local n = self:GetAttribute("kcr-" .. CUR .. "-n") or 0
    if n == 0 then return end
    local st = GetGamePadState()
    local s = st and st.sticks and st.sticks[self:GetAttribute("kcr-stick") or 2]
    if not s or not s.len or s.len < (self:GetAttribute("kcr-dead") or 0.35) then return end
    local ang = math.deg(math.atan2(s.x, s.y * (self:GetAttribute("kcr-invy") or 1)))
    ang = (ang - (ROT or 0)) % 360
    local best, bi = 1000, nil
    for i = 1, n do
        local a = self:GetAttribute("kcr-" .. CUR .. "-a" .. i) or 0
        local d = math.abs(((ang - a + 540) % 360) - 180)
        if d < best then best, bi = d, i end
    end
    return CUR, bi
]]

-- Bring up a ring: ring, and (for a drawer) the ring and index it was opened from.
RADIAL.SWITCH = [[
    local ring, from, fi = ...
    if not ring or (self:GetAttribute("kcr-" .. ring .. "-n") or 0) == 0 then return end
    local rot = 0
    local slot = self:GetFrameRef("kcr-" .. ring .. "-slot")
    if slot and from and fi then
        -- A drawer: turned so its current choice sits under the stick.
        local at = ((self:GetAttribute("kcr-" .. from .. "-a" .. fi) or 0) + (ROT or 0)) % 360
        local v, c = slot:GetAttribute("kcvalue"), 1
        if v ~= nil then
            for j = 1, self:GetAttribute("kcr-" .. ring .. "-n") or 0 do
                local f = self:GetFrameRef("kcr-" .. ring .. "-f" .. j)
                if f and f:GetAttribute("kcvalue") == v then c = j break end
            end
        end
        rot = (at - (self:GetAttribute("kcr-" .. ring .. "-a" .. c) or 0)) % 360
    end
    CUR, ROT = ring, rot
    local d = self:GetFrameRef("kcr-display")
    d:SetAttribute("kcr-rot", rot)
    d:SetAttribute("kcr-cur", ring)
]]

-- (A, B, X and Y go to the ring while it's up, except a key that's bound
-- to bring the ring up itself: its release has to reach the ring's binding.)
RADIAL.OPEN = [[
    if self:GetAttribute("kcr-isopen") then return true end
    if (self:GetAttribute("kcr-main-n") or 0) == 0 then return false end
    self:SetAttribute("kcr-isopen", true)
    self:RunAttribute("kcr-switch", "main")
    self:GetFrameRef("kcr-display"):Show()
    -- Pad buttons held right now go to the trigger while the ring is up:
    -- opened from a gamepad bar slot, that slot's button is still down, and
    -- letting it go then reaches the trigger (the game sends a release to
    -- whatever the key is bound to by then). Any modifier mix, so letting go
    -- of a trigger first doesn't matter. kcr-pk<i> is pad button i's key
    -- (modifiers and stick leans left out), set out of combat.
    -- No table literals or the keyword for making closures in a snippet, not
    -- even in a comment: the game refuses to compile it (BuildRestrictedClosure).
    local taken = "|"
    local st = GetGamePadState()
    local pressed, trig = st and st.buttons, self:GetAttribute("kcr-btn-trigger")
    if pressed and trig then
        for i = 1, (self:GetAttribute("kcr-pkn") or 0) do
            local key = pressed[i] and self:GetAttribute("kcr-pk" .. i)
            if key then
                self:SetBindingClick(true, key, trig, "LeftButton")
                self:SetBindingClick(true, "SHIFT-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "CTRL-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "CTRL-SHIFT-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "ALT-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "ALT-SHIFT-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "ALT-CTRL-" .. key, trig, "LeftButton")
                self:SetBindingClick(true, "ALT-CTRL-SHIFT-" .. key, trig, "LeftButton")
                taken = taken .. key .. "|"
                self:SetAttribute("kcr-held", true)
            end
        end
    end
    local t1, t2 = self:GetAttribute("kcr-trig1"), self:GetAttribute("kcr-trig2")
    local k = self:GetAttribute("kcr-key-use")
    if k and k ~= t1 and k ~= t2 and not strfind(taken, "|" .. k .. "|", 1, true) then self:SetBindingClick(true, k, self:GetAttribute("kcr-btn-use"), "LeftButton") end
    k = self:GetAttribute("kcr-key-back")
    if k and k ~= t1 and k ~= t2 and not strfind(taken, "|" .. k .. "|", 1, true) then self:SetBindingClick(true, k, self:GetAttribute("kcr-btn-back"), "LeftButton") end
    k = self:GetAttribute("kcr-key-open")
    if k and k ~= t1 and k ~= t2 and not strfind(taken, "|" .. k .. "|", 1, true) then self:SetBindingClick(true, k, self:GetAttribute("kcr-btn-open"), "LeftButton") end
    k = self:GetAttribute("kcr-key-alt")
    if k and k ~= t1 and k ~= t2 and not strfind(taken, "|" .. k .. "|", 1, true) then self:SetBindingClick(true, k, self:GetAttribute("kcr-btn-alt"), "LeftButton") end
    return true
]]

RADIAL.CLOSE = [[
    self:ClearBindings()
    self:SetAttribute("kcr-isopen", false)
    self:SetAttribute("kcr-held", false)
    self:SetAttribute("kcr-opener", nil)
    CUR, ROT = nil, 0
    local d = self:GetFrameRef("kcr-display")
    d:SetAttribute("kcr-cur", nil)
    d:Hide()
]]

-- What's under the stick: switch to its ring (Below the line, the way back,
-- a slot whose drawer is all it does) and say "ring", or say "use" with the
-- button to click. Nothing under it: nil.
RADIAL.USE = [[
    local ring, i = self:RunAttribute("kcr-pick")
    if not ring then return end
    local pre = "kcr-" .. ring
    if self:GetAttribute(pre .. "-k" .. i) == "ring" then
        self:RunAttribute("kcr-switch", self:GetAttribute(pre .. "-o" .. i), ring, i)
        return "ring"
    end
    local t = self:GetAttribute(pre .. "-t" .. i)
    if t then return "use", t end
]]

-- The binding that brings the ring up. Its press opens the ring; its release
-- uses what the stick points at (hold, lean, let go). Released with the stick
-- centred, the ring stays up (a tap), and the next press uses or, centred,
-- closes. A macro's /click is one release: it opens, then uses or closes;
-- from a gamepad bar the slot's button is still held, OPEN hands it to this
-- button, and letting it go is the release.
RADIAL.TRIGGER = [[
    self:SetAttribute("type", nil)
    if down then
        if not owner:GetAttribute("kcr-isopen") then
            if owner:RunAttribute("kcr-open") then owner:SetAttribute("kcr-held", true) end
        end
        return false
    end
    if not owner:GetAttribute("kcr-isopen") then
        owner:RunAttribute("kcr-open")
        return false
    end
    local held = owner:GetAttribute("kcr-held")
    owner:SetAttribute("kcr-held", false)
    local what, t = owner:RunAttribute("kcr-use")
    if what == "use" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/click " .. t)
        owner:RunAttribute("kcr-close")
        return
    end
    if what == "ring" or held then return false end
    owner:RunAttribute("kcr-close")
    return false
]]

-- A: use what the stick points at.
RADIAL.A = [[
    self:SetAttribute("type", nil)
    if down or not owner:GetAttribute("kcr-isopen") then return false end
    local what, t = owner:RunAttribute("kcr-use")
    if what == "use" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/click " .. t)
        owner:RunAttribute("kcr-close")
        return
    end
    return false
]]

-- B: back a ring, or close.
RADIAL.B = [[
    if down or not owner:GetAttribute("kcr-isopen") then return false end
    if CUR == "main" then
        owner:RunAttribute("kcr-close")
    else
        owner:RunAttribute("kcr-switch", owner:GetAttribute("kcr-" .. CUR .. "-up") or "main")
    end
    return false
]]

-- X: open what's behind the button the stick points at (a drawer, the row
-- under the line); with the stick centred on the main ring, the inner ring.
RADIAL.X = [[
    if down or not owner:GetAttribute("kcr-isopen") then return false end
    local ring, i = owner:RunAttribute("kcr-pick")
    if ring then
        local sub = owner:GetAttribute("kcr-" .. ring .. "-o" .. i)
        if sub then owner:RunAttribute("kcr-switch", sub, ring, i) end
    elseif CUR == "main" and (owner:GetAttribute("kcr-inner-n") or 0) > 0 then
        owner:RunAttribute("kcr-switch", "inner")
    end
    return false
]]

-- Y: the alternate (slot.radialAlt) of what the stick points at.
RADIAL.Y = [[
    self:SetAttribute("type", nil)
    if down or not owner:GetAttribute("kcr-isopen") then return false end
    local ring, i = owner:RunAttribute("kcr-pick")
    if not ring then return false end
    local m = owner:GetAttribute("kcr-" .. ring .. "-y" .. i)
    if not m then return false end
    self:SetAttribute("type", "macro")
    self:SetAttribute("macrotext", m)
    owner:RunAttribute("kcr-close")
]]

-- Gamepad bar buttons. The game sends a button's release to whatever took
-- its press, and the gamepad bar clicks the same bar button again on
-- release (GamepadMainActionBarFrame:PressActionButton keeps the owner), so
-- letting go of the bar slot whose macro opened the ring reaches that bar
-- button, never the ring. Each bar button's clicks are wrapped (out of
-- combat; Kit:RadialWrapBars): the press notes whether it opened the ring,
-- and that button's release uses what the stick points at, through the bar
-- button's own release action (pressAndHoldAction + typerelease, which
-- SecureActionButton runs on a release), put back straight after. Let go
-- with the stick centred (or on a drawer), the ring stays up as after a tap.
-- self is the bar button, owner the ring's header.
RADIAL.BARPRE = [[
    if down then
        if owner:GetAttribute("kcr-isopen") then return nil, "was" end
        return nil, "wasnt"
    end
    if not owner:GetAttribute("kcr-isopen") or owner:GetAttribute("kcr-opener") ~= self then return end
    owner:SetAttribute("kcr-opener", nil)
    owner:SetAttribute("kcr-held", false)
    local what, t = owner:RunAttribute("kcr-use")
    if what ~= "use" then return end
    self:SetAttribute("pressAndHoldAction", true)
    self:SetAttribute("typerelease", "macro")
    self:SetAttribute("macrotext", "/click " .. t)
    owner:RunAttribute("kcr-close")
    return nil, "used"
]]
RADIAL.BARPOST = [[
    if message == "wasnt" then
        if owner:GetAttribute("kcr-isopen") then owner:SetAttribute("kcr-opener", self) end
    elseif message == "used" then
        self:SetAttribute("pressAndHoldAction", nil)
        self:SetAttribute("typerelease", nil)
        self:SetAttribute("macrotext", nil)
    end
]]

-- The stick a kit reads: its index in the game's mapped state, found by the
-- name the game gives it ("Camera" is the right stick, "Movement" the left).
function RADIAL.StickIndex(which)
    local names = which == "left" and { "Movement", "Left" } or { "Camera", "Right" }
    local st = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local count = st and (st.stickCount or (st.sticks and #st.sticks)) or 0
    if C_GamePad and C_GamePad.StickIndexToConfigName then
        for _, want in ipairs(names) do
            for i = 1, count do
                local ok, n = pcall(C_GamePad.StickIndexToConfigName, i - 1)
                if ok and n == want then return i end
            end
        end
    end
    return which == "left" and 1 or 2
end

-- The stick as the snippets read it: x, y, length (nil if there's no pad).
function RADIAL.Stick(index)
    local st = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local s = st and st.sticks and st.sticks[index]
    if not s then return nil end
    return s.x or 0, s.y or 0, s.len or 0
end

-- Which of a ring's buttons the stick points at (the same sum as PICK).
function RADIAL.Index(items, rot, x, y, len)
    if not (items and #items > 0 and len and len >= RADIAL.DEAD) then return nil end
    local ang = (math.deg(math.atan2(x, y * RADIAL.INVERT_Y)) - (rot or 0)) % 360
    local best, bi = 1000, nil
    for i, it in ipairs(items) do
        local d = math.abs(((ang - it.a + 540) % 360) - 180)
        if d < best then best, bi = d, i end
    end
    return bi
end

-- Holding the camera still while a ring reads the right stick (or the
-- character still, for the left). Each frame the game sends the sticks'
-- raw events (Left, Right, Gyro) and then their twins (Movement, Camera,
-- Look), and acts on the twins. A frame that takes stick input and doesn't
-- pass it on, shown just before the twin of the stick we read, stops that
-- one alone; it hides again at the end of the frame. If a stick earlier in
-- the order moved this frame, its twin has to get past first, so the
-- stopper waits for it. (Seen in ConsolePort; propagation can't change in
-- combat, showing and hiding can, so both frames are set up once.) After
-- the ring closes it keeps holding until the stick is let go, so the
-- camera doesn't jump.
function RADIAL.Holder()
    if C.radialHold then return C.radialHold end
    local H = CreateFrame("Frame")
    local stop = CreateFrame("Frame")
    H:SetFrameStrata("BACKGROUND")
    stop:SetFrameStrata("TOOLTIP")
    Try(H.SetPropagateKeyboardInput, H, true)
    Try(stop.SetPropagateKeyboardInput, stop, false)
    Try(H.EnableGamePadStick, H, false)
    Try(stop.EnableGamePadStick, stop, true)
    stop:Hide()
    H.seen = {}
    H:SetScript("OnGamePadStick", function(_, stick, x, y, len) -- (errors, on a client without it: see the callers)
        if not H.raw then return end
        if stick == H.raw then
            if (len or 0) > 0 then
                local wait
                for _, r in ipairs(RADIAL.RAW) do
                    if r == H.raw then break end
                    if H.seen[r] then wait = RADIAL.VIRT[r] end
                end
                if wait then H.armed = wait else stop:Show() end
            elseif not H.open then
                H:Release() -- (closed, and the stick's back in the middle)
            end
        elseif stick == H.armed then
            H.armed = nil
            stop:Show()
        end
        if RADIAL.VIRT[stick] then H.seen[stick] = true end
    end)
    H:SetScript("OnUpdate", function()
        wipe(H.seen)
        H.armed = nil
        if stop:IsShown() then stop:Hide() end
    end)
    stop:SetScript("OnGamePadStick", function(_, stick)
        if stick == RADIAL.VIRT[H.raw or ""] then stop:Hide() end
    end)
    H:Hide()
    function H:Hold(which)
        self.raw = which == "left" and "Left" or "Right"
        self.open = true
        if self.timer then self.timer:Cancel() self.timer = nil end
        self:Show()
        Try(self.EnableGamePadStick, self, true)
    end
    -- The ring closed: keep holding until the stick's let go (or a second).
    function H:Closed()
        self.open = false
        if not self.raw then return end
        if C_Timer and C_Timer.NewTimer then
            if self.timer then self.timer:Cancel() end
            self.timer = C_Timer.NewTimer(1, function() H.timer = nil H:Release() end)
        else
            self:Release()
        end
    end
    function H:Release()
        if self.open then return end
        self.raw, self.armed = nil, nil
        Try(self.EnableGamePadStick, self, false)
        self:Hide()
        stop:Hide()
    end
    C.radialHold = H
    return H
end

-- The ring's art: what's on the kit's buttons, read as it's drawn.
local function RadialArt(kit, it)
    local b = it.btn
    if it.special then return nil end
    if it.choice then return Val(it.choice.icon), Val(it.choice.dim) end
    if not b then return nil end
    -- A slot that's hidden with the kit closed (the small ones) isn't
    -- painted by PaintAll, so it may have no icon yet: paint it now.
    if not (b:IsShown() or (b.twin and b.twin:IsShown())) then pcall(kit.PaintSlot, kit, b) end
    local tex = b.icon and b.icon:GetTexture()
    if not tex then
        -- (still none: what the button casts or uses)
        local sp = U.ButtonSpell(b)
        tex = sp and U.SpellIcon(sp)
        if not tex then
            local item = b:GetAttribute("item")
            local id = item and tonumber(tostring(item):match("item:(%d+)") or item)
            tex = id and U.ItemIcon(id)
        end
    end
    return tex, b.greyed
end

-- A button's name for the middle of the ring: what it casts or uses, else its label.
local function RadialName(kit, it)
    if it.special then return it.label end
    local c = it.choice or (it.btn and it.btn.assigned)
    if c and c.label then return c.label end
    local b = it.btn
    if c and c.spell then return U.SpellName(c.spell) or it.label end
    if c and c.item then return U.ItemName(c.item) or it.label end
    if b then
        local sp = U.ButtonSpell(b)
        if sp then
            local n = type(sp) == "number" and U.SpellName(sp) or sp
            if n and not U.Sealed(n) then return n end
        end
        local item = b:GetAttribute("item")
        if item then
            local id = tonumber(tostring(item):match("item:(%d+)") or item)
            local n = id and U.ItemName(id)
            if n then return n end
        end
    end
    return it.label
end

function Kit:RadialCfg()
    local r = self.db and self.db.radial
    if type(r) ~= "table" then return { on = true, stick = "right", camera = true, scale = 1, names = true } end
    return r
end

-- The slots in each ring, in order: zone lists if the kit has them, else
-- the kit's first ring, its small slots and the row under its line.
function Kit:RadialLists()
    local cfg = self.cfg
    local main, inner, below, seen = {}, {}, {}, {}
    local function Add(list, key)
        if seen[key] or not self.slots[key] then return end
        seen[key] = true
        list[#list + 1] = key
    end
    if cfg.zones then
        local lists = self:Zones()
        for _, z in ipairs(cfg.zones) do
            local dest = z.small and inner or (z.ring and main) or below
            for _, key in ipairs(lists[z.key] or {}) do Add(dest, key) end
        end
    else
        local rings = self:Rings()
        local belowSet = {}
        for _, key in ipairs(cfg.divider and cfg.divider.below or {}) do belowSet[key] = true end
        for _, ring in ipairs(rings) do
            for _, key in ipairs(ring.keys or {}) do
                local slot = self.slotByKey[key]
                if slot and not belowSet[key] then Add(slot.small and inner or main, key) end
            end
        end
        for _, key in ipairs(cfg.divider and cfg.divider.below or {}) do Add(below, key) end
    end
    -- (anything left: by its size)
    for _, slot in ipairs(cfg.slots) do Add(slot.small and inner or main, slot.key) end
    return main, inner, below
end

-- Out of combat, on every refresh: what's in each ring, for the snippets
-- (header attributes) and for drawing it (self.radial.rings).
function Kit:RadialRefresh()
    local R = self.radial
    if not R or InCombatLockdown() or self.trial then return end
    self:RadialWrapBars()
    local rc = self:RadialCfg()
    local on = rc.on ~= false and self.db.shown ~= false
    local function Usable(key)
        local b = self.slots[key]
        return on and b and not b.hidden and true or false
    end
    local rings = {}
    local function AltFor(slot, btn, choice, target)
        local alt = slot.radialAlt
        if not (alt and alt.macro) then return nil end
        local ok, m = pcall(alt.macro, self, btn, choice, target)
        return ok and m or nil
    end
    -- A slot's drawer as a ring of its own (its choices, as laid out).
    local function Drawer(key, up)
        local b = self.slots[key]
        local fly = b and b.fly
        if not (fly and (fly.count or 0) > 0) then return nil end
        local id = "d:" .. key
        local items = {}
        local m = math.min(fly.count, 16)
        for j = 1, m do
            local fb = fly.buttons[j]
            local c = fb and fb.choice
            if c then
                local name = fb:GetName()
                items[#items + 1] = { kind = "use", target = name, frame = fb, choice = c, btn = b,
                    label = c.label, alt = AltFor(b.slot, b, c, name), slot = b.slot }
            end
        end
        if #items == 0 then return nil end
        for j, it in ipairs(items) do it.a = (j - 1) * 360 / #items end
        rings[id] = { items = items, up = up, slot = b, drawer = true }
        return id
    end
    local function SlotItem(key, ringId)
        local b = self.slots[key]
        local slot = b.slot
        local it = { kind = "use", target = b:GetName(), btn = b, label = slot.label, slot = slot,
            small = slot.small and true or false }
        if b.fly then
            local sub = Drawer(key, ringId)
            if sub then
                it.open = sub
                -- (a drawer that opens on any click: using the slot is opening it)
                if slot.flyout == "left" then it.kind = "ring" end
            elseif slot.flyout == "left" then
                return nil
            end
        end
        it.alt = AltFor(slot, b, nil, it.target)
        return it
    end
    local mainKeys, innerKeys, belowKeys = self:RadialLists()
    local function Build(keys, ringId)
        local items = {}
        for _, key in ipairs(keys) do
            if Usable(key) then
                local it = SlotItem(key, ringId)
                if it then items[#items + 1] = it end
            end
        end
        return items
    end
    local below = Build(belowKeys, "below")
    local main = Build(mainKeys, "main")
    local inner = Build(innerKeys, "inner")
    -- Main: left to right over the top, clockwise; with a row under the line,
    -- its button at the bottom and the rest spread round from it.
    if #below > 0 then
        local step = 360 / (#main + 1)
        for i, it in ipairs(main) do it.a = (180 + i * step) % 360 end
        table.insert(main, 1, { kind = "ring", open = "below", special = "below", a = 180,
            label = Loc["Below the line"] })
        local stepB = 360 / (#below + 1)
        for i, it in ipairs(below) do it.a = (360 - i * stepB) % 360 end
        table.insert(below, 1, { kind = "ring", open = "main", special = "back", a = 0, label = Loc["Back to the ring"] })
        rings.below = { items = below, up = "main" }
    elseif #main > 0 then
        local step = 360 / #main
        for i, it in ipairs(main) do it.a = (180 + (i - 0.5) * step) % 360 end
    end
    -- Inner: spread round from the bottom, left to right as on the kit.
    if #inner > 0 then
        local step = 360 / #inner
        for i, it in ipairs(inner) do it.a = (180 - (i - (#inner + 1) / 2) * step) % 360 end
        rings.inner = { items = inner, up = "main" }
    end
    rings.main = { items = main }
    R.rings = rings

    -- Hand it to the header, only when something changed.
    local parts = {}
    for id, ring in pairs(rings) do
        parts[#parts + 1] = id .. "/" .. (ring.up or "") .. "/" .. #ring.items
        for i, it in ipairs(ring.items) do
            parts[#parts + 1] = ("%d:%s:%s:%.1f:%s:%s"):format(i, it.kind, it.target or "", it.a or 0, it.open or "", it.alt or "")
        end
    end
    table.sort(parts)
    R.stick = RADIAL.StickIndex(rc.stick)
    local sig = table.concat(parts, "|") .. "|" .. tostring(R.stick) .. "|" .. (rc.stick or "right")
    if sig == R.sig then return end
    R.sig = sig
    local h = R.header
    -- (rings from before that are gone: emptied)
    for id in pairs(R.pushed or {}) do
        if not rings[id] then h:SetAttribute("kcr-" .. id .. "-n", 0) end
    end
    R.pushed = {}
    for id, ring in pairs(rings) do
        local pre = "kcr-" .. id
        R.pushed[id] = true
        h:SetAttribute(pre .. "-n", #ring.items)
        h:SetAttribute(pre .. "-up", ring.up)
        if ring.drawer then SecureHandlerSetFrameRef(h, pre .. "-slot", ring.slot) end
        for i, it in ipairs(ring.items) do
            h:SetAttribute(pre .. "-a" .. i, it.a)
            h:SetAttribute(pre .. "-k" .. i, it.kind)
            h:SetAttribute(pre .. "-t" .. i, it.target)
            h:SetAttribute(pre .. "-o" .. i, it.open)
            h:SetAttribute(pre .. "-y" .. i, it.alt)
            if it.frame then SecureHandlerSetFrameRef(h, pre .. "-f" .. i, it.frame) end
        end
    end
    h:SetAttribute("kcr-stick", R.stick)
    if R.display:IsShown() then self:RadialDraw() end
end

-- Made once (out of combat, as the kit is built): the header and its
-- buttons, and the ring you see.
function Kit:BuildRadial()
    if self.radial or not self.cfg.radial then return end
    local P = self.prefix
    local R = {}
    self.radial = R
    local h = CreateFrame("Frame", P .. "RadialHeader", UIParent, "SecureHandlerBaseTemplate")
    R.header = h
    h:Execute([[ CUR = nil ROT = 0 ]])
    h:SetAttribute("kcr-pick", RADIAL.PICK)
    h:SetAttribute("kcr-switch", RADIAL.SWITCH)
    h:SetAttribute("kcr-open", RADIAL.OPEN)
    h:SetAttribute("kcr-close", RADIAL.CLOSE)
    h:SetAttribute("kcr-use", RADIAL.USE)
    h:SetAttribute("kcr-dead", RADIAL.DEAD)
    h:SetAttribute("kcr-invy", RADIAL.INVERT_Y)
    h:SetAttribute("kcr-stick", 2)
    h:SetAttribute("kcr-isopen", false)

    local function Button(suffix, body)
        local b = CreateFrame("Button", P .. "Radial" .. suffix, UIParent, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("useOnKeyDown", false)
        b:SetSize(1, 1)
        b:Hide()
        SecureHandlerWrapScript(b, "OnClick", h, body)
        return b
    end
    R.trigger = Button("", RADIAL.TRIGGER)
    h:SetAttribute("kcr-btn-trigger", R.trigger:GetName())
    local names = {}
    for role, body in pairs({ use = RADIAL.A, back = RADIAL.B, open = RADIAL.X, alt = RADIAL.Y }) do
        local b = Button(role:sub(1, 1):upper() .. role:sub(2), body)
        names[role] = b:GetName()
        h:SetAttribute("kcr-btn-" .. role, b:GetName())
        h:SetAttribute("kcr-key-" .. role, RADIAL.KEYS[role])
    end

    -- The ring you see: shown and hidden by the snippets (so it's secure
    -- itself), drawn by ordinary code on a plain frame inside it.
    local d = CreateFrame("Frame", P .. "RadialRing", UIParent, "SecureHandlerBaseTemplate")
    d:SetFrameStrata("DIALOG")
    d:SetSize(2, 2)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    d:Hide()
    R.display = d
    SecureHandlerSetFrameRef(h, "kcr-display", d)
    local v = CreateFrame("Frame", nil, d)
    v:SetSize(520, 600)
    v:SetPoint("CENTER")
    R.view = v
    self:RadialArtParts()
    d:HookScript("OnAttributeChanged", function(_, name)
        if name == "kcr-cur" or name == "kcr-rot" then self:RadialDraw() end
    end)
    d:HookScript("OnShow", function()
        local rc = self:RadialCfg()
        if rc.camera ~= false then pcall(function() RADIAL.Holder():Hold(rc.stick) end) end
        R.lastIndex = nil
        self:RadialDraw()
        GameTooltip:Hide()
        if R.debug and C_Timer then C_Timer.After(0, function() self:RadialDebugState("opened") end) end
    end)
    d:HookScript("OnHide", function()
        if C.radialHold then pcall(C.radialHold.Closed, C.radialHold) end
        if R.debug then self:RadialDebug("closed") end
    end)
    R.trigger:HookScript("OnClick", function(_, button, down)
        if R.debug then
            self:RadialDebug(("trigger %s (%s): ring now %s"):format(down and "PRESS" or "RELEASE", tostring(button),
                h:GetAttribute("kcr-isopen") and "open" or "closed"))
        end
    end)
    v:SetScript("OnUpdate", function(_, elapsed) self:RadialTick(elapsed) end)
    -- (the camera holder's frames are set up now, out of combat: whether they
    -- pass stick input on can't be set in a fight)
    pcall(RADIAL.Holder)
end

-- Debug readout (/<slash> radialdebug, out of combat): chat lines on what
-- the ring sees, to find out in game where a press or release goes.
-- English only, on purpose: it's for whoever is testing.
function Kit:RadialDebug(msg)
    print("|cffd8b4ff" .. self.prefix .. " radial:|r " .. tostring(msg))
end

local function PadKeyAction(key)
    if not (key and GetBindingAction) then return "?" end
    local a = GetBindingAction(key, true)
    return (a and a ~= "") and a or "(nothing)"
end

function Kit:RadialDebugState(what)
    local R = self.radial
    if not (R and R.debug) then return end
    local h = R.header
    local held = {}
    local st = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    if st and st.buttons then
        for i, down in pairs(st.buttons) do
            if down then
                local name = C_GamePad.ButtonIndexToBinding and C_GamePad.ButtonIndexToBinding(i - 1)
                held[#held + 1] = ("#%s %s, taken as %s, bound to %s"):format(tostring(i), tostring(name),
                    tostring(h:GetAttribute("kcr-pk" .. i)), PadKeyAction(name))
            end
        end
    end
    local wrapped = 0
    for _ in pairs(R.barWrapped or {}) do wrapped = wrapped + 1 end
    self:RadialDebug(("%s. pad state: %s; held now: %s; held flag: %s; keys mapped: %s; bar buttons wrapped: %d; opened by a bar button: %s"):format(what,
        st and "yes" or "NONE", #held > 0 and table.concat(held, " | ") or "none",
        tostring(h:GetAttribute("kcr-held")), tostring(h:GetAttribute("kcr-pkn")), wrapped,
        h:GetAttribute("kcr-opener") and "yes" or "no"))
end

function Kit:RadialDebugToggle()
    local R = self.radial
    if not R then self:Print("No radial in this kit.") return end
    R.debug = not R.debug
    if R.debug and not R.debugPad then
        -- Sees every pad press and release first, passing it on to the game.
        local f = CreateFrame("Frame")
        pcall(f.SetPropagateKeyboardInput, f, true)
        f:EnableGamePadButton(true)
        f:SetScript("OnGamePadButtonDown", function(_, key)
            if R.debug then self:RadialDebug(("pad PRESS %s, bound to %s"):format(tostring(key), PadKeyAction(key))) end
        end)
        f:SetScript("OnGamePadButtonUp", function(_, key)
            if R.debug then self:RadialDebug(("pad RELEASE %s, bound to %s"):format(tostring(key), PadKeyAction(key))) end
        end)
        R.debugPad = f
    end
    if R.debugPad then R.debugPad:SetShown(R.debug) end
    self:RadialDebug(R.debug and "debug on (same command turns it off)" or "debug off")
    if R.debug then self:RadialDebugState("now") end
end

-- The parts of the ring you see (made once).
function Kit:RadialArtParts()
    local R, v = self.radial, self.radial.view
    local M = self.media
    local bg = v:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetTexture(M .. "circle_mask")
    bg:SetVertexColor(0.05, 0.04, 0.07, 0.82)
    bg:SetPoint("CENTER", 0, 30)
    R.bg = bg
    local rim = v:CreateTexture(nil, "BACKGROUND", nil, -6)
    rim:SetTexture(M .. "glow_ring")
    rim:SetBlendMode("ADD")
    rim:SetVertexColor(0.85, 0.7, 0.35, 0.55)
    rim:SetPoint("CENTER", bg)
    R.rim = rim
    -- The middle: the kit's own button (or the slot a drawer came from).
    local mid = CreateFrame("Frame", nil, v)
    mid:SetSize(84, 84)
    mid:SetPoint("CENTER", bg, "CENTER", 0, 8)
    mid.icon = mid:CreateTexture(nil, "ARTWORK")
    mid.icon:SetPoint("TOPLEFT", 9, -9)
    mid.icon:SetPoint("BOTTOMRIGHT", -9, 9)
    local mask = mid:CreateMaskTexture()
    mask:SetTexture(M .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(mid.icon)
    mid.icon:AddMaskTexture(mask)
    mid.ring = mid:CreateTexture(nil, "OVERLAY", nil, 6)
    mid.ring:SetAllPoints()
    mid.text = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    mid.text:SetPoint("CENTER", 0, 1)
    mid.text:SetTextColor(1, 1, 1)
    mid.text:SetShadowOffset(1, -1)
    mid.badge = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mid.badge:SetPoint("BOTTOM", mid, "TOP", 0, 2)
    mid.badge:SetTextColor(0.72, 0.68, 0.8)
    R.mid = mid
    -- What the stick points at, under the middle.
    R.title = v:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    R.title:SetPoint("TOP", mid, "BOTTOM", 0, -6)
    R.title:SetWidth(230)
    R.title:SetWordWrap(false)
    R.sub = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    R.sub:SetPoint("TOP", R.title, "BOTTOM", 0, -3)
    R.sub:SetWidth(240)
    R.sub:SetTextColor(0.75, 0.72, 0.82)
    -- The pointer: a small arrow inside the ring, toward what's picked.
    R.arrow = v:CreateTexture(nil, "OVERLAY")
    R.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    R.arrow:SetVertexColor(0.95, 0.8, 0.45)
    R.arrow:SetSize(26, 26)
    R.arrow:Hide()
    -- The divider, over the middle of the ring under the line.
    if self.divider and self.divider.tex then
        R.line = v:CreateTexture(nil, "ARTWORK")
        R.line:SetSize(220, 14)
        R.line:Hide()
    end
    -- The button prompts along the bottom.
    R.prompts = {}
    local bar = CreateFrame("Frame", nil, v)
    bar:SetSize(10, 28)
    bar:SetPoint("BOTTOM", v, "BOTTOM", 0, 0)
    R.bar = bar
    R.cells = {}
end

-- One button on the ring (made as needed).
function Kit:RadialCell(i)
    local R = self.radial
    local w = R.cells[i]
    if w then return w end
    local M = self.media
    w = CreateFrame("Frame", nil, R.view)
    w:SetSize(RADIAL.ICON, RADIAL.ICON)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetPoint("TOPLEFT", 2, -2)
    w.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    local mask = w:CreateMaskTexture()
    mask:SetTexture(M .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(w.icon)
    w.icon:AddMaskTexture(mask)
    w.ring = w:CreateTexture(nil, "OVERLAY", nil, 6)
    w.ring:SetPoint("TOPLEFT", -1, 1)
    w.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    w.glow = w:CreateTexture(nil, "BACKGROUND")
    w.glow:SetTexture(M .. "glow_ring")
    w.glow:SetBlendMode("ADD")
    w.glow:SetPoint("CENTER")
    w.glow:Hide()
    C.glows[w.glow] = true
    w.sel = w:CreateTexture(nil, "BACKGROUND", nil, 1)
    w.sel:SetTexture(M .. "glow_ring")
    w.sel:SetBlendMode("ADD")
    w.sel:SetVertexColor(1, 0.88, 0.55)
    w.sel:SetPoint("CENTER")
    w.sel:Hide()
    w.arrow = w:CreateTexture(nil, "OVERLAY", nil, 7)
    w.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    w.arrow:SetVertexColor(0.95, 0.8, 0.45)
    w.arrow:SetPoint("CENTER")
    w.arrow:Hide()
    -- (a button that opens something: a small gold chevron on its corner)
    w.badge = w:CreateTexture(nil, "OVERLAY", nil, 7)
    w.badge:SetTexture("Interface\\Minimap\\MinimapArrow")
    w.badge:SetVertexColor(0.95, 0.8, 0.45)
    w.badge:SetSize(14, 14)
    w.badge:SetPoint("CENTER", w, "TOPRIGHT", -3, -3)
    w.badge:SetRotation(-math.pi / 2)
    w.count = w:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    w.count:SetPoint("BOTTOMRIGHT", -1, 1)
    w.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.label:SetPoint("TOP", w, "BOTTOM", 0, -2)
    w.label:SetWidth(110)
    w.label:SetWordWrap(false)
    R.cells[i] = w
    return w
end

-- Draw the ring that's up (any time: it's all plain frames and textures).
function Kit:RadialDraw()
    local R = self.radial
    if not R then return end
    local d = R.display
    local id = d:GetAttribute("kcr-cur")
    local ring = id and R.rings and R.rings[id]
    for _, w in ipairs(R.cells) do w:Hide() end
    R.arrow:Hide()
    if R.line then R.line:Hide() end
    R.lastIndex, R.promptsFor = nil, false
    if not ring then return end
    local rc = self:RadialCfg()
    R.view:SetScale(math.max(0.5, math.min(2, tonumber(rc.scale) or 1)))
    local rot = tonumber(d:GetAttribute("kcr-rot")) or 0
    R.id, R.ring, R.rot = id, ring, rot
    local inner = id == "inner"
    local radius = inner and RADIAL.RADIUS * 0.62 or RADIAL.RADIUS
    local bgSize = (radius + RADIAL.ICON + 26) * 2
    R.bg:SetSize(bgSize, bgSize)
    R.rim:SetSize(bgSize * 1.04, bgSize * 1.04)
    R.radius = radius
    local cx, cy = 0, 30
    for i, it in ipairs(ring.items) do
        local w = self:RadialCell(i)
        local size = it.small and RADIAL.SMALL or RADIAL.ICON
        it.size = size
        w:SetSize(size, size)
        w.glow:SetSize(size * 1.7, size * 1.7)
        w.sel:SetSize(size * 1.9, size * 1.9)
        if it.small then
            w.ring:SetTexture(self.media .. "ring_prof_" .. ArtSize(ScreenPx(w, size), PROF_RING_SIZES), nil, nil, "LINEAR")
        else
            w.ring:SetTexture(self.media .. "ring_slot_" .. ArtSize(ScreenPx(w, size + 2), ART_SIZES), nil, nil, "LINEAR")
        end
        local a = math.rad((it.a + rot) % 360)
        w:ClearAllPoints()
        w:SetPoint("CENTER", R.view, "CENTER", cx + radius * math.sin(a), cy + radius * math.cos(a))
        w.label:SetShown(rc.names ~= false)
        w.label:SetText(it.label or "")
        w.badge:SetShown(it.open and not it.special and true or false)
        w.arrow:Hide()
        if it.special then
            w.icon:SetColorTexture(0.09, 0.07, 0.12, 1)
            w.icon:SetDesaturated(false)
            w.arrow:SetSize(size * 0.5, size * 0.5)
            w.arrow:SetRotation(it.special == "below" and math.pi or 0)
            w.arrow:Show()
        end
        w:Show()
    end
    -- The middle: the kit's button, or for a drawer the slot it came from.
    local mid, kit = R.mid, self.kit
    mid.text:SetText("")
    mid.badge:SetText("")
    if ring.drawer and ring.slot then
        local icon = ring.slot.icon and ring.slot.icon:GetTexture()
        mid.icon:SetTexture(icon or 134400)
        mid.icon:SetTexCoord(0, 1, 0, 1)
        mid.ring:SetTexture(self.media .. "ring_slot_128", nil, nil, "LINEAR")
        mid.badge:SetText(ring.slot.slot.label)
    else
        mid.icon:SetTexture(kit.icon:GetTexture())
        mid.icon:SetTexCoord(kit.icon:GetTexCoord())
        if kit.ring and kit.ring:GetTexture() then
            mid.ring:SetTexture(kit.ring:GetTexture(), nil, nil, "LINEAR")
        else
            mid.ring:SetTexture(self.media .. "ring_slot_128", nil, nil, "LINEAR")
        end
        if kit.text then mid.text:SetText(kit.text:GetText() or "") end
        if id == "inner" then mid.badge:SetText(Loc["Inner ring"]) end
        if id == "below" then mid.badge:SetText(Loc["Below the line"]) end
    end
    mid:SetSize(inner and 60 or 84, inner and 60 or 84)
    if R.line and id == "below" then
        R.line:SetTexture(self.divider.tex:GetTexture(), nil, nil, "LINEAR")
        R.line:ClearAllPoints()
        R.line:SetPoint("BOTTOM", mid, "TOP", 0, 14)
        R.line:Show()
    end
    self:RadialPaint()
end

-- Icons, glows and counts as they are now (on each tick, cheaply).
function Kit:RadialPaint()
    local R = self.radial
    local ring = R and R.ring
    if not ring then return end
    for i, it in ipairs(ring.items) do
        local w = R.cells[i]
        if w and not it.special then
            local tex, grey = RadialArt(self, it)
            w.icon:SetTexture(tex or 134400)
            w.icon:SetDesaturated(grey and true or false)
            local v = grey and 0.6 or 1
            w.icon:SetVertexColor(v, v, v)
            local b = it.btn
            local glow = not it.choice and b and b.glow and b.glow:IsShown()
            if glow then
                local c = self.cfg.glowColor or { 1, 0.82, 0.3 }
                w.glow:SetVertexColor(c[1], c[2], c[3])
            end
            w.glow:SetShown(glow and true or false)
            local n = it.choice and Val(it.choice.count) or (not it.choice and b and b.count and b.count:IsShown() and b.count:GetText())
            w.count:SetText((n and n ~= 0 and n ~= "" and (tonumber(n) or 2) > 1) and n or "")
        elseif w and it.special == "below" then
            -- (something under the line wants you: the button glows)
            local any = false
            for _, x in ipairs(R.rings.below and R.rings.below.items or {}) do
                if x.btn and x.btn.glow and x.btn.glow:IsShown() then any = true end
            end
            if any then
                local c = self.cfg.glowColor or { 1, 0.82, 0.3 }
                w.glow:SetVertexColor(c[1], c[2], c[3])
            end
            w.glow:SetShown(any)
        end
    end
end

-- A prompt: the pad button's own picture where the game has one, else its letter.
local GLYPH_LETTER = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
local GLYPH_COLOR = { PAD1 = { 0.14, 0.48, 0.21 }, PAD2 = { 0.79, 0.16, 0.16 }, PAD3 = { 0.11, 0.38, 0.74 }, PAD4 = { 0.88, 0.66, 0 } }
function Kit:RadialPrompt(i, key, text)
    local R = self.radial
    local p = R.prompts[i]
    if not p then
        p = CreateFrame("Frame", nil, R.bar)
        p:SetSize(10, 26)
        p.disc = p:CreateTexture(nil, "ARTWORK")
        p.disc:SetSize(24, 24)
        p.disc:SetPoint("LEFT")
        local mask = p:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(p.disc)
        p.disc:AddMaskTexture(mask)
        p.pic = p:CreateTexture(nil, "OVERLAY")
        p.pic:SetSize(26, 26)
        p.pic:SetPoint("CENTER", p.disc)
        p.letter = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        p.letter:SetPoint("CENTER", p.disc)
        p.letter:SetTextColor(1, 1, 1)
        p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        p.text:SetPoint("LEFT", p.disc, "RIGHT", 6, 0)
        R.prompts[i] = p
    end
    local pic
    local util = _G.InputIconTextureSetUtility
    if util and util.GetNormalActiveInputIconButtonTexture then
        local ok, t = pcall(util.GetNormalActiveInputIconButtonTexture, key)
        if ok and type(t) == "string" and t ~= "" then pic = t end
    end
    if pic then
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(pic) then p.pic:SetAtlas(pic) else p.pic:SetTexture(pic) end
        p.pic:Show()
        p.disc:Hide()
        p.letter:SetText("")
    else
        local c = GLYPH_COLOR[key] or { 0.3, 0.3, 0.3 }
        p.disc:SetColorTexture(c[1], c[2], c[3], 1)
        p.disc:Show()
        p.pic:Hide()
        p.letter:SetText(GLYPH_LETTER[key] or key)
        p.letter:SetTextColor(key == "PAD4" and 0.1 or 1, key == "PAD4" and 0.08 or 1, key == "PAD4" and 0.03 or 1)
    end
    p.text:SetText(text)
    p:SetWidth(30 + p.text:GetStringWidth())
    p:Show()
    return p
end

-- Each frame while it's up: what the stick points at, lit, named, prompted.
function Kit:RadialTick(elapsed)
    local R = self.radial
    local ring = R and R.ring
    if not ring then return end
    R.paintIn = (R.paintIn or 0) - (elapsed or 0)
    if R.paintIn <= 0 then
        R.paintIn = 0.2
        self:RadialPaint()
    end
    local x, y, len = RADIAL.Stick(R.stick or 2)
    local i = RADIAL.Index(ring.items, R.rot, x or 0, y or 0, len)
    if i == R.lastIndex and R.promptsFor == i then return end
    R.lastIndex = i
    for j, w in ipairs(R.cells) do
        local on = (j == i)
        w.sel:SetShown(on)
        local it = ring.items[j]
        if it and w:IsShown() then
            local size = (it.size or RADIAL.ICON) * (on and 1.18 or 1)
            w:SetSize(size, size)
            w.label:SetTextColor(on and 1 or 0.92, on and 0.95 or 0.86, on and 0.8 or 0.7)
        end
    end
    local it = i and ring.items[i]
    if it then
        local a = math.rad((it.a + (R.rot or 0)) % 360)
        local r = (R.id == "inner" and 40 or 58)
        R.arrow:ClearAllPoints()
        R.arrow:SetPoint("CENTER", R.view, "CENTER", r * math.sin(a), 30 + r * math.cos(a))
        R.arrow:SetRotation(-a)
        R.arrow:Show()
        R.title:SetText(RadialName(self, it))
        R.sub:SetText((it.slot and not it.choice and it.slot.label ~= R.title:GetText()) and it.slot.label or "")
    else
        R.arrow:Hide()
        R.title:SetText("")
        R.sub:SetText(R.id == "main" and R.rings.inner and Loc["Stick centred + X: inner ring"] or Loc["Tilt the stick"])
    end
    -- The prompts for what's under the stick.
    R.promptsFor = i
    for _, p in ipairs(R.prompts) do p:Hide() end
    local K = RADIAL.KEYS
    local list = {}
    if it then
        if it.kind == "use" then list[#list + 1] = { K.use, it.choice and Loc["Cast"] or Loc["Use"] }
        else list[#list + 1] = { K.use, Loc["Open"] } end
        if it.open and it.kind == "use" then list[#list + 1] = { K.open, Loc["Open"] } end
        local alt = it.alt and it.slot and it.slot.radialAlt
        if alt then
            -- (offered unless ready says no; a ready that errors doesn't hide it)
            local ok, ready = true, true
            if alt.ready then ok, ready = pcall(alt.ready, self) end
            if not ok or ready then list[#list + 1] = { K.alt, Val(alt.label, self) or Loc["Alternate"] } end
        end
    elseif R.id == "main" and R.rings.inner then
        list[#list + 1] = { K.open, Loc["Inner ring"] }
    end
    list[#list + 1] = { K.back, R.id == "main" and Loc["Close"] or Loc["Back"] }
    local wTotal, gap, cells = 0, 22, {}
    for n, e in ipairs(list) do
        local p = self:RadialPrompt(n, e[1], e[2])
        cells[n] = p
        wTotal = wTotal + p:GetWidth() + (n > 1 and gap or 0)
    end
    local xPos = -wTotal / 2
    for _, p in ipairs(cells) do
        p:ClearAllPoints()
        p:SetPoint("LEFT", R.bar, "CENTER", xPos, 0)
        xPos = xPos + p:GetWidth() + gap
    end
    R.bar:ClearAllPoints()
    R.bar:SetPoint("TOP", R.bg, "BOTTOM", 0, -6)
end

-- The keys bound to bring the ring up (out of combat, as bindings change).
-- Wraps the gamepad bar's buttons (RADIAL.BARPRE/BARPOST), once each, out
-- of combat. The bars come with the Gamepad UI, which may load after the
-- kit, so this runs again on every refresh until they're there.
function Kit:RadialWrapBars()
    local R = self.radial
    if not R or InCombatLockdown() then return end
    local unit = _G.GamepadMainActionBarFrame and _G.GamepadMainActionBarFrame.PageUnit
    if not (unit and type(unit.actionBars) == "table" and SecureHandlerWrapScript) then return end
    R.barWrapped = R.barWrapped or {}
    for _, bar in pairs(unit.actionBars) do
        if type(bar) == "table" and type(bar.actionButtons) == "table" then
            for _, b in pairs(bar.actionButtons) do
                if type(b) == "table" and not R.barWrapped[b] and b.IsProtected and b:IsProtected() then
                    if pcall(SecureHandlerWrapScript, b, "OnClick", R.header, RADIAL.BARPRE, RADIAL.BARPOST) then
                        R.barWrapped[b] = true
                    end
                end
            end
        end
    end
end

function Kit:RadialKeys()
    local R = self.radial
    if not R or InCombatLockdown() then return end
    local k1, k2
    if GetBindingKey then k1, k2 = GetBindingKey("CLICK " .. self.prefix .. "Radial:LeftButton") end
    R.header:SetAttribute("kcr-trig1", k1)
    R.header:SetAttribute("kcr-trig2", k2)
    -- Pad button i's key, for OPEN to hand a held button to the trigger.
    -- Left out: anything the game must see let go of itself (the triggers,
    -- buttons acting as Shift/Ctrl/Alt, the Gamepad UI's bar-swap and
    -- targeting modifiers, which keep state between press and release) and
    -- stick leans (PADLSTICKUP and so on: letting the stick go would count).
    local skip = { [GAMEPAD_TRIGGER_LEFT or "PADLTRIGGER"] = true, [GAMEPAD_TRIGGER_RIGHT or "PADRTRIGGER"] = true }
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    for _, m in ipairs({ "Shift", "Ctrl", "Alt" }) do
        local ok, v = pcall(getCVar, "GamePadEmulate" .. m)
        if ok and type(v) == "string" and v ~= "" then skip[v] = true end
    end
    if GetBindingKey then
        for _, action in ipairs({ "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD", "GAMEPADLEFTTARGETMODIFIER",
                "GAMEPADRIGHTTARGETMODIFIER", "TOGGLEPINGSYSTEM" }) do
            local got = { pcall(GetBindingKey, action, true) }
            for j = 2, got[1] and #got or 1 do
                if type(got[j]) == "string" then skip[got[j]:match("([^%-]+)$") or got[j]] = true end
            end
        end
    end
    local toKey = C_GamePad and C_GamePad.ButtonIndexToBinding
    local n = 0
    for i = 1, 64 do
        local key
        if toKey then
            local ok, b = pcall(toKey, i - 1)
            if ok and type(b) == "string" and b ~= "" and not skip[b] and not b:find("STICK%u") then key = b end
        end
        R.header:SetAttribute("kcr-pk" .. i, key)
        if key then n = i end
    end
    R.header:SetAttribute("kcr-pkn", n)
end

-- A macro for a gamepad bar (/click <prefix>Radial), picked up on the cursor
-- to drop on a bar slot. Out of combat.
function Kit:RadialMacro()
    if InCombatLockdown() then self:Print(Loc["That can only change out of combat."]) return end
    if not (CreateMacro and GetMacroIndexByName) then return end
    local name = (self.prefix .. "Ring"):sub(1, 16)
    local body = "/click " .. self.prefix .. "Radial"
    local icon = self.cfg.macroIcon or "INV_MISC_QUESTIONMARK"
    local index = GetMacroIndexByName(name)
    if index == 0 then
        local ok, made = pcall(CreateMacro, name, icon, body, false)
        index = ok and made or 0
    else
        pcall(EditMacro, index, name, nil, body)
    end
    if not index or index == 0 then
        self:Print(Loc["Couldn't make the macro: your macro slots may be full."], true)
        return
    end
    if PickupMacro then PickupMacro(index) end
    self:Print((Loc["Macro \"%s\" is on your cursor: drop it on a gamepad bar slot."]):format(name), true)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local BASE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "BAG_UPDATE_COOLDOWN",
    "SPELL_UPDATE_COOLDOWN", "UPDATE_BINDINGS", "ITEM_DATA_LOAD_RESULT", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "SPELL_UPDATE_USABLE",
}

function Kit:OnEvent(event, ...)
    local cfg = self.cfg
    if event == "ADDON_LOADED" then
        if ... ~= cfg.addon then return end
        local db = _G[cfg.db] or {}
        local cdb = _G[cfg.charDb] or {}
        _G[cfg.db], _G[cfg.charDb] = db, cdb
        if cfg.defaults then U.ApplyDefaults(db, cfg.defaults) end
        U.ApplyDefaults(db, C.BASE_DEFAULTS)
        if cfg.alwaysHideInCombat then db.hideInCombat = true end
        if cfg.charDefaults then U.ApplyDefaults(cdb, cfg.charDefaults) end
        U.ApplyDefaults(cdb, C.BASE_CHAR)
        self.db, self.cdb = db, cdb
        for _, slot in ipairs(cfg.slots) do
            cdb.pinned[slot.key] = (not slot.noPin and cdb.pinned[slot.key]) and true or false
        end
        self:CleanBars()
        self:CleanZones()
        self:ApplyZones()
        self.events:UnregisterEvent("ADDON_LOADED")
        return
    elseif event == "PLAYER_LOGIN" then
        return self:Build()
    end
    if not self.built then return end

    local h = cfg.events and cfg.events[event]
    if h then h(self, ...) end
    local uh = cfg.unitEvents and cfg.unitEvents[event]
    if uh then uh.fn(self, ...) end

    if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" then
        self:Refresh(false)
    elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        self:PaintAll()
    elseif event == "SPELL_UPDATE_USABLE" or (event == "UNIT_POWER_UPDATE" and ... == "player") then
        self:PaintMana()
    elseif event == "UPDATE_BINDINGS" then
        self:UpdateHotkeys()
        if self.radial then self:RadialKeys() end
    elseif event:find("^GAME_PAD_") then
        -- (another pad, or its sticks set up differently: which stick is which)
        if self.radial and not InCombatLockdown() then
            self.radial.sig = nil
            self:RadialRefresh()
            self:RadialKeys()
        end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- Item info arriving (often in bursts at login): one refresh shortly after.
        if self.refreshQueued or not C_Timer then return end
        self.refreshQueued = true
        C_Timer.After(0.5, function()
            self.refreshQueued = false
            self:Refresh(false)
        end)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        self:PaintAll()
        self:ApplyShapes()
    elseif event == "GLOBAL_MOUSE_DOWN" then
        local fly = self.flyOpen
        if fly and fly:IsShown() and not InCombatLockdown() then
            local focus = GetMouseFoci and GetMouseFoci()[1] or (GetMouseFocus and GetMouseFocus())
            local inside = false
            while focus do
                if focus == fly or focus == fly.slotBtn or (fly.anchorTo and focus == fly.anchorTo) then inside = true break end
                focus = focus.GetParent and focus:GetParent()
            end
            if not inside then fly:Hide() end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        GameTooltip:Hide()
        if self.editing then self:SetEdit(false) end -- (the layout is only edited out of combat)
        if self:HidesInCombat() and not InCombatLockdown() then self.holder:Hide() end
        -- Combat is about to start (still allowed now): flyouts opened from
        -- here on, and any open already, close themselves once the mouse
        -- leaves them, since a click elsewhere can't close them in combat.
        if not InCombatLockdown() then
            -- A drawer opened from a reminder (v32) is out of combat only:
            -- it closes, back beside its slot.
            for _, f in pairs(self.flyouts or {}) do
                if f.anchorTo and f:IsShown() then f:Hide() end
            end
            -- Anything part-way through hiding hides now (see Fighting): a
            -- slot closing, or the kit fading out as another kit opens.
            self:FinishSlides()
            if self.tucked and self.kit:IsShown() then
                if self.kit.fadeAG then self.kit.fadeAG:Stop() end
                self.kit:Hide()
            end
            self:PushMoveInfo() -- (the button's scale, as it is now)
            if self.grip then self.grip:SetShown(self:CanSecureToggle() or self:CanSecureMove()) end -- (see GRIP_CLICK)
            local delay = tonumber(self.db.flyoutHide) or 0.5
            delay = math.min(2, math.max(0.2, delay))
            self.header:SetAttribute("kchide", delay)
            self.header:SetAttribute("kccombat", true)
            pcall(self.header.Execute, self.header, ([[
                for i = 1, NFLY do
                    local f = FLYOUTS[i]
                    if f:IsShown() then
                        f:RegisterAutoHide(%s)
                        f:AddToAutoHide(FLYSLOTS[i])
                    end
                end
            ]]):format(delay))
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.header:SetAttribute("kccombat", false)
        pcall(self.header.Execute, self.header, [[ for i = 1, NFLY do FLYOUTS[i]:UnregisterAutoHide() end ]])
        if self.db.hideInCombat then self.holder:Show() end
        if self.pending then
            self:ApplyPosition()
            self:ApplyCombatHide()
        end
        if self.grip then
            self.grip:Hide()
            self.grip:ClearAllPoints()
            self.grip:SetAllPoints(self.kit)
        end
        self:StopGhost()
        self.combatPress = nil
        if self.qkbLeavePending then self:QkbRestore() end -- (Quick Keybind Mode closed in combat)
        if self.radial then self:RadialKeys() end -- (bindings changed in combat)
        if self.editLeavePending then self:EditRestore() end -- (so did the layout's edit mode)
        self:Refresh(false)
        -- Moved or opened in combat: catch the dock up a frame from now (see
        -- FinishCombatMove), the move first, so the dock lays the kit out
        -- where it was dropped, then where it opened or closed.
        if self.combatDrop or self.combatToggled or self.pinMoved then
            local function After()
                if InCombatLockdown() then return end -- (in a fight again: next time)
                self:FinishCombatMove()
                if self.combatToggled then
                    self.combatToggled = nil
                    local D = self.Dock
                    if D and D.Opening and D.Closed then
                        if self.open then D.Opening(self.key) else D.Closed(self.key) end
                    end
                    self:KeepOnScreen()
                end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, After) else After() end
        end
    end
end

---------------------------------------------------------------------------
-- Quick Keybind Mode (from v15)
--
-- While the game's Quick Keybind Mode is up, every kit opens fully, and each
-- slot, corner button and kit button gets a cover that works like an action
-- button in that mode: hover it and press a key (or a mouse button, or the
-- wheel) to bind it, Escape to unbind. The cover sits over the secure button
-- so a click in this mode never uses the item or spell underneath.
-- On the pin with other kits, each kit opens in place, fanned in its own
-- slice (as in combat), so none takes the pin and they can all be open.
-- Kits in a Kit Dock tuck box come out of it, full size along its edge (Kit
-- Dock v25), and go back in after. A kit that was open before goes back to
-- open after; the rest close.
---------------------------------------------------------------------------

local QKB_IDLE = 0.5            -- the covers' ring while not hovered
local QKB_COLOR = { 0.45, 0.8, 1 } -- (blue, so it isn't mistaken for a reminder glow)

local function InQuickKeybind()
    local f = _G.QuickKeybindFrame
    return f and f:IsShown() and true or false
end
U.InQuickKeybind = InQuickKeybind

-- On the pin with other kits and open only for Quick Keybind Mode: Kit Dock
-- is told it's closed, so it doesn't hand it the pin and tuck the rest.
function Kit:QkbInPlace()
    if not self.qkbOpen then return false end
    local D = self.Dock
    return D and D.IsDocked and D.IsDocked(self.key) and not (D.EdgeSide and D.EdgeSide(self.key)) and true or false
end

-- What can be bound in this kit: { frame, binding command }.
function Kit:QkbTargets()
    local list = {}
    local H = self.cfg.bindingHeader
    if H then list[#list + 1] = { self.kit, H .. "_TOGGLE", 1.3 } end
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        if btn then
            list[#list + 1] = { btn, "CLICK " .. btn:GetName() .. ":LeftButton", slot.small and 1.7 or 1.6 }
            local sb = btn.sub
            if sb then list[#list + 1] = { sb, "CLICK " .. sb:GetName() .. ":LeftButton", 1.7 } end
        end
    end
    return list
end

-- The tooltip the game shows over an action button in this mode. (The mode
-- calls this on the hovered button after each key, by this name.)
local function QkbTooltip(ov)
    local tip = _G.QuickKeybindTooltip or GameTooltip
    tip:SetOwner(ov, "ANCHOR_RIGHT")
    local cmd = ov.commandName
    tip:AddLine(GetBindingName and GetBindingName(cmd) or cmd, 1, 1, 1)
    local key = GetBindingKey(cmd)
    if key then
        tip:AddLine(GetBindingText and GetBindingText(key) or key, 0.1, 1, 0.1)
        tip:AddLine(ESCAPE_TO_UNBIND or Loc["Press Escape to unbind."], 1, 0.82, 0)
    else
        tip:AddLine(NOT_BOUND or Loc["Not bound"], 1, 0.1, 0.1)
        tip:AddLine(PRESS_KEY_TO_BIND or Loc["Press a key to bind."], 1, 0.82, 0)
    end
    tip:Show()
end

local function QkbFrame() return _G.QuickKeybindFrame end

-- The cover over one bindable button (made the first time it's needed, out
-- of combat).
function Kit:QkbCover(frame, command, mul)
    local ov = frame.kcQkb
    if not ov then
        ov = CreateFrame("Button", nil, frame)
        ov:SetAllPoints(frame)
        ov:RegisterForClicks("AnyUp")
        ov:EnableMouseWheel(true)
        ov:Hide()
        local hl = ov:CreateTexture(nil, "OVERLAY", nil, 7)
        hl:SetTexture(self.media .. "glow_ring")
        hl:SetBlendMode("ADD")
        hl:SetPoint("CENTER")
        hl:SetVertexColor(QKB_COLOR[1], QKB_COLOR[2], QKB_COLOR[3])
        ov.hl = hl
        ov.QuickKeybindButtonSetTooltip = QkbTooltip
        ov:SetScript("OnEnter", function(o)
            local f = QkbFrame()
            if not (f and f:IsShown()) then return end
            Try(f.SetSelected, f, o.commandName, o)
            o.hl:SetAlpha(1)
            QkbTooltip(o)
        end)
        ov:SetScript("OnLeave", function(o)
            local f = QkbFrame()
            if f and f:IsShown() then Try(f.SetSelected, f, nil, nil) end
            o.hl:SetAlpha(QKB_IDLE)
            local tip = _G.QuickKeybindTooltip
            if tip then tip:Hide() end
            GameTooltip:Hide()
        end)
        ov:SetScript("OnClick", function(o, button)
            -- (left and right clicks do nothing here, as on the action bars;
            -- other mouse buttons get bound)
            local f = QkbFrame()
            if f and f:IsShown() and button ~= "LeftButton" and button ~= "RightButton" then
                Try(f.OnKeyDown, f, button)
            end
        end)
        ov:SetScript("OnMouseWheel", function(o, delta)
            local f = QkbFrame()
            if f and f:IsShown() then Try(f.OnMouseWheel, f, delta) end
        end)
        frame.kcQkb = ov
    end
    ov.commandName = command
    ov:SetFrameLevel(frame:GetFrameLevel() + 20)
    ov.hl:SetSize(frame:GetWidth() * mul, frame:GetHeight() * mul)
    ov.hl:SetAlpha(QKB_IDLE)
    return ov
end

function Kit:QkbCovers(on)
    for _, t in ipairs(self:QkbTargets()) do
        local frame = t[1]
        if on then
            if not InCombatLockdown() or frame.kcQkb then self:QkbCover(frame, t[2], t[3]):Show() end
        elseif frame.kcQkb then
            frame.kcQkb:Hide()
        end
    end
end

-- Entering the mode, step 1 (every kit, before any opens): an open kit
-- closes, so one that took the pin hands it back first.
function Kit:QkbClose()
    if not self.built or self.qkbOpen or InCombatLockdown() then return end
    self.qkbWasOpen = self.open
    self:CloseFlyouts()
    if self.open then self:SetOpen(false) end
end

-- Step 2: open fully, in place on the pin, and put the covers on.
function Kit:QkbOpen()
    if not self.built or self.qkbOpen or InCombatLockdown() then return end
    self.qkbOpen = true
    self.qkbLeavePending = nil
    if self.db.shown ~= false then
        self.open = true
        self:Refresh("open")
        self:ApplyFade()
    end
    self:QkbCovers(true)
end

-- Leaving the mode: covers off now; the kit goes back as it was once it's
-- out of combat.
function Kit:QkbLeave(reopenLater)
    self:QkbCovers(false)
    if not self.qkbOpen then return end
    if InCombatLockdown() then self.qkbLeavePending = true return end
    self:QkbRestore(reopenLater)
end

-- Closes what the mode opened. A kit that was open before opens again now,
-- or (reopenLater) once the dock has put every kit back (QkbReopen).
function Kit:QkbRestore(reopenLater)
    self.qkbLeavePending = nil
    if not self.qkbOpen or InCombatLockdown() then return end
    self.qkbOpen = nil
    local was = self.qkbWasOpen
    self.qkbWasOpen = nil
    if self.open then
        self.open = false
        self:Refresh("close")
        local D = self.Dock
        if D and D.Closed then D.Closed(self.key) end
    end
    self.qkbReopen = was and true or nil
    if not reopenLater then self:QkbReopen() end
    self:ArmOpenFade()
    self:ApplyFade()
end

function Kit:QkbReopen()
    local was = self.qkbReopen
    self.qkbReopen = nil
    if was and self.db.shown ~= false and not InCombatLockdown() then self:SetOpen(true) end
end

-- The mode opened or closed (the game's frame showing or hiding).
function C.SetQuickKeybind(on)
    on = on and true or false
    if C.qkb == on then return end
    C.qkb = on
    local kits = C.kits or {}
    local D
    for _, kit in ipairs(kits) do D = D or kit.Dock end
    if on then
        if InCombatLockdown() then C.qkb = false return end
        for _, kit in ipairs(kits) do
            if kit.editing then pcall(kit.SetEdit, kit, false) end -- (one mode at a time)
        end
        for _, kit in ipairs(kits) do pcall(kit.QkbClose, kit) end
        for _, kit in ipairs(kits) do pcall(kit.QkbOpen, kit) end
        -- Kits on an edge lay out with room for being open, and the tuck
        -- boxes let their kits out.
        if D then pcall(D.SetQuickKeybind or D.Layout, true) end
    else
        -- Close what the mode opened, then the boxes take their kits back,
        -- then kits that were open before open again (from the box, if
        -- that's where they live).
        for _, kit in ipairs(kits) do pcall(kit.QkbLeave, kit, true) end
        if D and D.SetQuickKeybind then pcall(D.SetQuickKeybind, false) end
        for _, kit in ipairs(kits) do pcall(kit.QkbReopen, kit) end
    end
end

-- Follow the game's Quick Keybind frame. It's in its own Blizzard addon,
-- which may load after the kits. Hooked once for all copies; the hook calls
-- through C, so a newer copy's SetQuickKeybind is the one that runs.
local function HookQuickKeybind()
    local f = _G.QuickKeybindFrame
    if C.qkbHooked or not f or not f.HookScript then return end
    C.qkbHooked = true
    f:HookScript("OnShow", function() C.SetQuickKeybind(true) end)
    f:HookScript("OnHide", function() C.SetQuickKeybind(false) end)
    if f:IsShown() then C.SetQuickKeybind(true) end
end
C.qkbWatch = C.qkbWatch or CreateFrame("Frame")
C.qkbWatch:RegisterEvent("ADDON_LOADED")
C.qkbWatch:RegisterEvent("PLAYER_LOGIN")
C.qkbWatch:SetScript("OnEvent", function(f, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_QuickKeybind" then return end
    HookQuickKeybind()
    if C.qkbHooked then f:UnregisterAllEvents() end
end)
HookQuickKeybind()

function Kit:Build()
    local cfg = self.cfg
    self:BuildKit()
    for _, slot in ipairs(cfg.slots) do self:CreateSlot(slot) end
    self.built = true
    C.kits = C.kits or {}
    C.kits[#C.kits + 1] = self -- (for Quick Keybind Mode, and the reminder panel)
    -- The reminder panel: which slots go there (reminders unless you untick
    -- them), and its shared settings brought in line with the other kits'.
    self.db.panelSlots = self.db.panelSlots or {}
    for _, slot in ipairs(cfg.slots) do
        if self.db.panelSlots[slot.key] == nil then self.db.panelSlots[slot.key] = self:PanelDefault(slot) end
    end
    C.SyncPanel()
    C.PlacePanel()
    self:UpdateHotkeys()
    self:ApplyPosition()
    self:RegisterDock()
    self:BuildArea()
    self:RegisterForeverUI()
    self:ApplyCombatHide()
    self.kit:SetShown(self.db.shown ~= false)
    if cfg.AfterBuild then cfg.AfterBuild(self) end
    self:SetupSettings()
    self:SetupMinimap()
    if cfg.radial then
        self:BuildRadial()
        self:RadialKeys()
        for _, e in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED" }) do
            pcall(self.events.RegisterEvent, self.events, e)
        end
    end

    for _, e in ipairs(BASE_EVENTS) do pcall(self.events.RegisterEvent, self.events, e) end
    for e in pairs(cfg.events or {}) do pcall(self.events.RegisterEvent, self.events, e) end
    for e, u in pairs(cfg.unitEvents or {}) do
        pcall(self.events.RegisterUnitEvent, self.events, e, unpack(u.units))
    end
    -- Your mana, for the red tint (with the kit's own units, if it watches power too).
    local pu = cfg.unitEvents and cfg.unitEvents.UNIT_POWER_UPDATE
    local units = { "player" }
    for _, u in ipairs(pu and pu.units or {}) do
        if u ~= "player" then units[#units + 1] = u end
    end
    pcall(self.events.RegisterUnitEvent, self.events, "UNIT_POWER_UPDATE", unpack(units))

    -- Twice a second: anything the kit watches that raises no event.
    if cfg.Tick then
        local ticker = CreateFrame("Frame", nil, self.holder)
        ticker:SetScript("OnUpdate", function(f, elapsed)
            f.acc = (f.acc or 0) + elapsed
            if f.acc < 0.5 then return end
            f.acc = 0
            cfg.Tick(self)
        end)
    end
    self:Refresh(false)
end
