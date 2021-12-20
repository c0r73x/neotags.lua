{
    order: 'pftsicmv',
    kinds: {
        p: { group: 'neotags_PreProcTag' },
        c: { group: 'neotags_ConstantTag' },
        t: { group: 'neotags_TypeTag' },
        s: { group: 'neotags_StructTag' },
        i: { group: 'neotags_InterfaceTag' },
        v: { group: 'neotags_GlobalVarTag' },
        f: {
          group: 'neotags_functionTag',
          suffix: [[\>\%(\s*(\|\s*:\?=\s*func\)\@=]],
        },
        m: {
          group: 'neotags_MemberTag',
          prefix: [[\%(\%(\>\|\]\|)\)\.\)\@5<=]],
        },
    }
}
