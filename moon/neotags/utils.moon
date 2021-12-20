class Utils
    concat: (a, b) ->
        return a if not b
        return b if not a

        result = {unpack(a)}
        table.move(b, 1, #b, #result + 1, result)
        return result

    explode: (div, str) ->
        return false if div == ''

        pos,arr = 0, {}

        for st, sp in () -> string.find(str,div,pos,true)
            table.insert(arr, string.sub(str, pos, st - 1))
            pos = sp + 1

        return arr

return Utils
