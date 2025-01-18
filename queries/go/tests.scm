;; extends

; Inspired by: https://github.com/leoluz/nvim-dap-go/blob/1bacf2fa7d4dc6a8a4f6cc390f1544e5b34c35a4/lua/dap-go-ts.lua#L10
(
  function_declaration
    name: (identifier) @func_name
    parameters: (parameter_list
      (parameter_declaration
        name: (identifier)*
        type: (pointer_type
          (qualified_type
            (package_identifier) @package
            (type_identifier) @type
          )
        )
      )+
    )
  (#match? @func_name "^Test.+$")
  (#eq? @package "testing")
  (#eq? @type "T")
) @func
