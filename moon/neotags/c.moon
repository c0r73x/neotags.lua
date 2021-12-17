{
    order: 'guesmfdtv',
    kinds: {
        g: {
            group: 'neotags_EnumTypeTag',
            prefix: [[\%(enum\s\+\)\@5<=]]
        },
        u: {
            group: 'neotags_UnionTag',
            prefix: [[\%(union\s\+\)\@6<=]]
        },
        e: { group: 'neotags_EnumTag' },
        s: {
            group: 'neotags_StructTag',
            prefix: [[\%(struct\s\+\)\@7<=]]
        },
        m: {
            group: 'neotags_MemberTag',
            prefix: [[\%(\%(\>\|\]\|)\)\%(\.\|->\)\)\@5<=]],
        },
        f: { group: 'neotags_FunctionTag' },
        d: { group: 'neotags_PreProcTag' },
        t: {
            group: 'neotags_TypeTag',
            suffix: [[\>\%(\.\|->\)\@!]]
        },
        v: { group: 'neotags_GlobalVarTag' }
    }
}
