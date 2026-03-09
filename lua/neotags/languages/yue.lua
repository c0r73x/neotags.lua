local notin = { 
'vim.*', 
'.*Comment.*', 
'.*String.*', 
'yueKeyword', 
'yueObjAssign' }return { order = 



'cifmspv', kinds = { c = { group = 

'neotags_ClassTag', notin = notin }, i = { group = 
'neotags_ImportTag', notin = notin }, f = { group = 
'neotags_FunctionTag', notin = notin }, m = { group = 
'neotags_FunctionTag', notin = notin }, v = { group = 

'neotags_VariableTag', allow_keyword = 
false, notin = 
notin }, s = { group = 

'neotags_EnumTag', notin = notin }, p = { group = 

'neotags_TypeTag', allow_keyword = 
false, notin = 
notin } } }