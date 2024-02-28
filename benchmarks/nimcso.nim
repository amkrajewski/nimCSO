import ../src/nimcso
import ../src/nimcso/bitArrayAutoconfigured
import std/terminal
import std/times
import std/strutils
import std/sequtils

echo nimcso.elementOrder

block:
    styledEcho fgBlue, "\nCount Data Points Prevented by Removal of Cr-Fe-Ni-Co-Al (nimCSO BitArray Representation)\n", resetStyle

    let presenceBitArrays = getPresenceBitArrays()
    let memoryUsed =((
        presenceBitArrays.sizeof + 
        (presenceBitArrays[0].sizeof + presenceBitArrays[0].bits.sizeof + presenceBitArrays[0].bits[0].sizeof) * len(presenceBitArrays)
        ).float/1024).formatFloat(format = ffDecimal, precision = 1)
    echo "Memory to Store Dataset:", memoryUsed, "kB"

    let t0 = epochTime()
    for i in 1..100000:
        block:
            var bb = BitArray()
            for i in 0..5: 
                bb[i] = true
            discard preventedData(bb, presenceBitArrays)
    let elapsed = (epochTime() - t0) * 10
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
    styledEcho "CPU Time [per dataset evaluation] ", styleBright, fgGreen, elapsedStr, "μs", resetStyle
    let elapsedPC = elapsed / nimcso.dataN * 1000
    let elapsedStrPC = elapsedPC.formatFloat(format = ffDecimal, precision = 1)
    styledEcho "CPU Time [per comparison] ", styleBright, fgGreen, elapsedStrPC, "ns\n", resetStyle

block:
    styledEcho fgBlue, "\nCount Data Points Prevented by Removal of Cr-Fe-Ni-Co-Al (nimCSO Int Representation)\n", resetStyle

    let presenceIntArray = getPresenceIntArray()
    let a = 0b00000000000000000000000000000000_00000000000000000000000000111111'u64
    assert preventedData(a, presenceIntArray) == 1955

    let memoryUsed = (presenceIntArray.sizeof.float / 1024).formatFloat(format = ffDecimal, precision = 1)
    echo "Memory to Store Dataset:", memoryUsed, "kB"

    let t0 = epochTime()
    for i in 1..100000:
        block:
            let b = 0b00000000000000000000000000000000_00000000000000000000000000111111'u64
            discard preventedData(b, presenceIntArray)
    let elapsed = (epochTime() - t0) * 10
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
    styledEcho "CPU Time [per dataset evaluation] ", styleBright, fgGreen, elapsedStr, "μs", resetStyle
    let elapsedPC = elapsed / nimcso.dataN * 1000
    let elapsedStrPC = elapsedPC.formatFloat(format = ffDecimal, precision = 3)
    styledEcho "CPU Time [per comparison] ", styleBright, fgGreen, elapsedStrPC, "ns", resetStyle