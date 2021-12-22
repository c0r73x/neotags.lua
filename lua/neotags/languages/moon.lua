return {
  order = 'cifmspv',
  kinds = {
    c = {
      group = 'neotags_ClassTag'
    },
    i = {
      group = 'neotags_ImportTag'
    },
    f = {
      group = 'neotags_FunctionTag'
    },
    m = {
      group = 'neotags_FunctionTag'
    },
    v = {
      group = 'neotags_VariableTag',
      allow_keyword = false
    },
    s = {
      group = 'neotags_EnumTag'
    },
    p = {
      group = 'neotags_TypeTag'
    }
  }
}
