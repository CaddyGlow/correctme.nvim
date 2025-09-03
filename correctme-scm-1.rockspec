package = "correctme"
version = "scm-1"
source = {
   url = "git+https://github.com/caddyglow/correctme.nvim.git"
}
description = {
   summary = "AI-powered code correction plugin for Neovim",
   detailed = "Neovim plugin that uses LLM providers to correct and improve code",
   homepage = "https://github.com/caddyglow/correctme.nvim",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
}
test_dependencies = {
   "busted >= 2.0.0",
}
build = {
   type = "builtin",
}