local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = { }

	local a = ssu.makeAdder(result)

	a("R::NalathanEchtzeitPlugin", {
		gravity = { 0.5, 0.5 },
	})

	a("R::NalathanEchtzeitPlugin Button", {
		gravity = { 0, 0.5 },
		padding = { 1, 10, 1, 10 },
	})

	a("Window#nalathanEchtzeitWindow", {
		minSize = { 440, -1 },
	})

	a("Window#nalathanEchtzeitWindow Window::Content", {
		padding = { 12, 14, 16, 14 },
	})

	a("R::NalathanEchtzeitPanel BoxLayout", {
		innerSpacing = { 10, 10 },
	})

	a("R::NalathanEchtzeitPanel !label", {
		minSize = { 90, -1 },
	})

	a("R::NalathanEchtzeitPanel TextInputField", {
		minSize = { 200, 30 },
	})

	a("R::NalathanEchtzeitPanel Button", {
		padding = { 6, 12, 6, 12 },
	})

	return result
end
