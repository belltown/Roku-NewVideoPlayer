' FormatJSON, A Roku JSON encoder. Version 0.0
'
' Copyright (c) 2014, belltown. All rights reserved.
'
' Redistribution and use in source and binary forms, with or without
' modification, are permitted provided that the following conditions are met:
'   * Redistributions of source code must retain the above copyright
'       notice, this list of conditions and the following disclaimer.
'   * Redistributions in binary form must reproduce the above copyright
'       notice, this list of conditions and the following disclaimer in the
'       documentation and/or other materials provided with the distribution.
'   * Neither the name of the copyright holder nor the names the contributors may be used to endorse or promote products
'       derived from this software without specific prior written permission.
'
' THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
' ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
' WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
' DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY
' DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
' (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
' LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
' ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
' (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
' SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'-------------------------------------------------------------------------------------------------------------------------

' Usage:
'
'
' References:
'   JSON    : ECMA-404 (informal) / RFC 4627 (obsolete - referenced in Roku docs) / RFC 7159 (latest)
'   UTF-8   : RFC 3629
'   UTF-16  : ISO/IEC 10646 Annex Q, and RFC 2781
'
' Notes:
' - In accordance with RFC 7159, any supported data type may be formatted, not just objects and arrays
' - Json escape sequences (\.) are used for: quote (34), backslash (92), backspace (98), form-feed (12), line-feed (10), carriage return (13), tab (9)
' - By default, a forward slash is not escaped; it optionally may be backslash-escaped (\/)
' - All non-printable characters other than Json backslash-escaped characters are Unicode-escaped (\uhhhh)
' - All valid RFC 3629 UTF-8 sequences (1 to 4 octets) should be correctly handled
' - All invalid UTF-8 sequences should be detected and substituted with the Unicode 'Replacement character' (U+FFFD)
' - Unicode code points desigated as noncharacters "intended for process-internal uses" (e.g. U+FFFE, U+FFFF) are allowed and are Unicode-escaped
' - In accordance with ISO/IEC 10646, all invalid Unicode code points are detected and substituted with the Unicode 'Replacement character' (U+FFFD)
' - Roku strings cannot contain embedded nulls. If your data contains embedded nulls, read it into an roByteArray
' - By default, an roByteArray is formatted as a character string (embedded nulls allowed); it optionally may be formatted as an array of unsigned integers
' - Unlike Roku's FormatJson function, works on all known Roku models and firmware versions (including fw. 3)
' - Unlike Roku's FormatJson function, handles all valid UTF-8 sequences
' - Designed to handle Unicode character data; therefore, should not be used to format arbitrary binary data (which may contain data that is not valid Unicode)
' - Self-referential objects/circular references, etc., are not checked for and will result in a stack overflow; they're not supposed to be representable in Json anyway

' TODO: byte arrays containing nulls (substitute with DEL characters???)

function createJsonFormatter () as object
    this = {}                                   ' The JsonFormatter object returned from this function
    this.ba = CreateObject ("roByteArray")      ' The main byte array holds the formatted json string in byte form; it is converted to ASCII at the end
    this.ba.SetResize (64 * 1024, true)         ' Make it big to start with. TODO: Auto-resize in increments (perf test first)
    this.baAppendItem = CreateObject ("roByteArray")    ' For appending individual items to the main byte array
    this.replacementChar = "\uFFFD"             ' Unicode 'Replacement character' string. Call SetReplacementChar ("?") to change it to a different string
    this.solidus = 0                            ' If SetEscapeSolidus (true) was called, the backslash-escape character value for the solidus "/"
    this.baAsString = true                      ' By default, an roByteArray is formatted as a string; SetByteArrayAsString (false) will format it as array of ints
    this.errorList = []                         ' Keep a list of all formatting errors
    this.invalidUtf8 = false                    ' Must set to false for strings before each octet to be processed
    this.baHex = CreateObject ("roByteArray")   ' Hex integer to String conversion
    this.baHex.SetResize (4, false)             ' Only need 2 bytes for a hex number, but allow 4 just in case larger numbers handled eventually
    this.stats = {}

    ' < 0   => non-printing character (use Unicode-encoding)
    ' = 0   => ASCII printable character
    ' > 0   => escaped character (use backslash-encoding)
    '
    ' 8     - BS    \b
    ' 9     - TAB   \t
    ' 10    - LF    \n
    ' 12    - FF    \f
    ' 13    - CR    \r
    ' 34    - "     \"
    ' 47    - /     \/  [not escaped by default, unless SetEscapeSolidus (true) called]
    ' 92    - \     \\
    this.esc = [-1, -1, -1, -1, -1, -1, -1, -1, 98, 116, 110, -1, 102, 114, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 34,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, this.solidus, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1 ]

    ' Main formatting function. Returns a Json-formatted string from a BrightScript value
    this.FormatJson = function (j as dynamic) as string
            m.ba.Clear ()
            m.formatValue (m.ba, j)
            return m.ba.ToAsciiString ()
    end function

    ' Set the character used to substitute for invalid UTF-8 octets
    ' Default is "\uFFFD", the Unicode 'Replacement character'
    ' Use "" to skip invalid octets
    this.SetReplacementChar = function (replacement = "\uFFFD" as string)
            this.replacementChar = replacement
    end function

    ' Escaping the solidus is optional
    this.SetEscapeSolidus = function (escape = false as boolean)
            if escape
                m.solidus = 47
            else
                m.solidus = 0
            endif
            m.esc [47] = m.solidus
    end function

    '
    this.SetByteArrayAsString = function (baAsString = true as boolean)
            m.baAsString = baAsString
    end function

    ' Convert a string value to bytes and append to the main byte array
    this.baAppend = function (s as string)
            m.baAppendItem.FromAsciiString (s)
            m.ba.Append (m.baAppendItem)
    end function

    ' Debugging code only
    this.inc = function (s as string)
        key = m.stats.Lookup (s)
        if key = invalid
            m.stats [s] = 1
        else
            m.stats [s] = m.stats [s] + 1
        endif
    end function

    ' Debugging code only
    this.printStats = function ()
        for each key in m.stats
            print key, m.stats [key]
        end for
    end function

    ' Recursively format each Roku item in turn
    this.formatValue = function (mba as object, j as dynamic)
            t = type (j)

            ' In my test data, String, Integer and Boolean intrinsic types were the most common, so test for them first
            if t = "String"
                'm.inc ("String")
                m.formatString (mba, j)
            else if t = "Integer"
                'm.inc ("Integer")
                m.baAppend (j.ToStr ())
            else if t = "Boolean"
                'm.inc ("Boolean")
                if j
                    ' true
                    mba.Push (116) : mba.Push (114) : mba.Push (117) : mba.Push (101)
                else
                    ' false
                    mba.Push (102) : mba.Push (97) : mba.Push (108) : mba.Push (115) : mba.Push (101)
                endif

            ' Invalid was the next most common type
            else if t = "Invalid"
                'm.inc ("Invalid")
                ' null
                mba.Push (110) : mba.Push (117) : mba.Push (108) : mba.Push (108)

            ' roAssociativeArray and roArray components were quite common too
            else if t = "roAssociativeArray"
                'm.inc ("roAssociativeArray")
                m.formatAA (mba, j)
            else if t = "roArray"
                'm.inc ("roArray")
                m.formatArray (mba, j)

            ' Then came the Floats
            else if t = "Float"
                'm.inc ("Float")
                m.baAppend (Str (j))

            ' Now test for the less common types
            else if t = "roString"
                'm.inc ("roString")
                m.formatString (mba, j)
            else if t = "roList"
                'm.inc ("roList")
                m.formatArray (mba, j)
            else if t = "roInt"
                'm.inc ("roInt")
                m.baAppend (j.ToStr ())
            else if t = "roInteger"
                'm.inc ("roInteger")
                m.baAppend (j.ToStr ())
            else if t = "roFloat"
                'm.inc ("roFloat")
                m.baAppend (Str (j))        ' No need to trim the leading space; whitespace is allowed and ignored in Json text
            else if t = "roDouble"
                'm.inc ("roDouble")
                m.baAppend (Str (j))
            else if t = "Double"
                'm.inc ("Double")
                m.baAppend (Str (j))
            else if t = "roIntrinsicDouble"
                'm.inc ("roIntrinsicDouble")
                m.baAppend (Str (j))
            else if t = "roBoolean"
                'm.inc ("roBoolean")
                if j then m.baAppend ("true") else m.baAppend ("false")
            else if t = "roByteArray"
                'm.inc ("roByteArray")
                if m.baAsString
                    m.formatByteArrayAsString (j)
                else
                    m.formatArray (mba, j)
                endif
            else if t = "roInvalid"
                'm.inc ("roInvalid")
                m.baAppend ("null")
            else if t = "roDateTime"
                m.baAppend (Chr (34) + m.formatDateTime (j) + Chr (34))

            ' Just in case we've missed something, check interfaces as well
            else if GetInterface (j, "ifString") <> invalid
                'm.inc ("ifString")
                m.formatString (mba, j)
            else if GetInterface (j, "ifInt") <> invalid
                'm.inc ("ifInt")
                m.baAppend (j.ToStr ())
            else if GetInterface (j, "ifBoolean") <> invalid
                'm.inc ("ifBoolean")
                if j then m.baAppend ("true") else m.baAppend ("false")
            'else if GetInterface (j, "ifFloat") <> invalid or GetInterface (j, "ifDouble") <> invalid
            else if GetInterface (j, "ifFloat") <> invalid
                'm.inc ("ifFloat")
                m.baAppend (Str (j))
            else if GetInterface (j, "ifDouble") <> invalid
                'm.inc ("ifDouble")
                m.baAppend (Str (j))
            'else if GetInterface (j, "ifArray") <> invalid or GetInterface (j, "ifList")
            else if GetInterface (j, "ifArray") <> invalid
                'm.inc ("ifArray")
                m.formatArray (mba, j)
            else if GetInterface (j, "ifList") <> invalid
                'm.inc ("ifList")
                m.formatArray (mba, j)

            ' Catchall - format unknowns as strings with a value of the type name
            else
                'm.inc ("Unknown" + t)
                m.formatString (mba, t)
                m.errorList.Push ("Unknown object: " + t)   ' Flag as error
            endif
    end function

    ' TODO - test what happens when invalid Unicode used in AA key e.g. \uDEAD
    this.formatAA = function (mba as object, j as object)
            mba.Push (123)                  ' {
            if not j.IsEmpty ()
                for each key in j
                    mba.Push (34)           ' "
                    m.baAppend (key)
                    mba.Push (34)           ' "
                    mba.Push (58)           ' :
                    m.formatValue (mba, j [key])
                    mba.Push (44)           ' '
                end for
                mba.Pop ()                  ' Pop trailing comma
            endif
            mba.Push (125)                  ' }
    end function

    this.formatArray = function (mba as object, j as object)
            mba.Push (91)                   ' [
            if j.Count () > 0
                ' Format the first item
                m.formatValue (mba, j[0])
                ' Format each subsequent item with a preceding ","
                for i = 1 to j.Count () - 1
                    mba.Push (44)           ' ,
                    m.formatValue (mba, j[i])
                end for
            endif
            mba.Push (93)                   ' ]
    end function

    ' Convert an integer to a 4-character hex string
    this.hex = function (h as integer) as string
            m.baHex [0] = h / 256
            m.baHex [1] = h Mod 256
            return m.baHex.ToHexString ()
    end function

    this.formatByteArrayAsString = function (mba as object, ba as object)
            nChars = ba.Count ()                                ' Number of input bytes
            mba.Push (34)                                       ' Opening quote
            ba.Push (1) : ba.Push (1) : ba.Push (1)             ' To handle truncated UTF-8 4-byte sequence

            i = 0
            while i < nChars

                '---------------------------
                ' Get the Unicode code point
                '---------------------------

                m.invalidUtf8 = false                           ' Set to true in m.invalidChar if an invalid sequence is detected
                REM cp = 0                                      ' Unicode code point value -- initial assignment not needed here (optimization)
                c = ba [i]                                      ' Current UTF-8 octet being examined
                octets = 1                                      ' Keep track of how many valid octets comprise the current code point

                ' 1-byte UTF-8/ASCII (most of the time this is all we do)
                if c < &H80
                    cp = c                                      ' Byte #1

                ' Out of place continuation byte, or C0/C1 (overlong 2-byte encoding)
                else if c <= &HC1
                    m.invalidChar (i, "Invalid Byte #1 (U+80-U+C1)")

                ' 2-byte UTF-8
                else if c < &HE0    ' 11100000
                    cp = c - &HC0                               ' Byte #1
                    c = ba [i + 1]
                    if c >= &H80 and c < &HC0
                        cp = (cp * 64) + c - &H80               ' Byte #2
                        octets = 2
                    else
                        m.invalidChar (i, "Invalid UTF-8 Byte #2 (< U+80)")
                    endif

                ' 3-byte UTF-8
                else if c < &HF0    ' 11110000
                    cp = c - &HE0   ' 11100000                  ' Byte #1
                    c = ba [i + 1]
                    if c >= &H80 and c < &HC0
                        cp = (cp * 64) + c - &H80               ' Byte #2
                        c = ba [i + 2]
                        if c >= &H80 and c < &HC0
                            cp = (cp * 64) + c - &H80           ' Byte #3
                            if cp >= &H0800                     ' not overlong
                                octets = 3
                            else
                                m.invalidChar (i, "Overlong 3-byte code point")
                            endif
                        else
                            m.invalidChar (i, "Invalid UTF-8 Byte #3 (< U+80)")
                        endif
                    else
                        m.invalidChar (i, "Invalid UTF-8 Byte #2 (< U+80)")
                    endif

                ' 4-byte UTF-8
                else if c < &HF8    ' 11111000
                    cp = c - &HF0   ' 11110000                  ' Byte #1
                    c = ba [i + 1]
                    if c >= &H80 and c < &HC0
                        cp = (cp * 64) + c - &H80               ' Byte #2
                        c = ba [i + 2]
                        if c >= &H80 and c < &HC0
                            cp = (cp * 64) + c - &H80           ' Byte #3
                            c = ba [i + 3]
                            if c >= &H80 and c < &HC0
                                cp = (cp * 64) + c - &H80       ' Byte #4
                                if cp >= &H10000                ' not overlong ???????????????????????? < ???????
                                    octets = 4
                                else
                                    m.invalidChar (i, "Overlong 4-byte code point")
                                endif
                            else
                                m.invalidChar (i, "Invalid UTF-8 Byte #4 (< U+80)")
                            endif
                        else
                            m.invalidChar (i, "Invalid UTF-8 Byte #3 (< U+80)")
                        endif
                    else
                        m.invalidChar (i, "Invalid UTF-8 Byte #2 (< U+80)")
                    endif

                else
                    m.invalidChar (i, "Invalid UTF-8 Byte #1 (>= U+F8)")
                endif

                '------------------------------------------------------------------------------------------------
                ' Convert the Unicode code point to a Json string value (\uhhhh) or surrogate pair (\uhhhh\uhhhh)
                '------------------------------------------------------------------------------------------------

                if not m.invalidUtf8

                    ' ASCII character (U+0000 to U+007F)
                    if cp < &H80
                        c = m.esc [cp]

                        ' Printable character
                        if c = 0
                            mba.Push (cp)

                        ' Backslash-escaped character
                        else if c > 0
                            mba.Push (92)       ' \
                            mba.Push (c)

                        ' Nonprintable, unicode-escaped character
                        else
                            mba.Push (92)       ' \
                            mba.Push (117)      ' u
                            m.baAppend (m.hex (cp))

                        endif

                    ' Valid Unicode 16-bit character (U+0080 to U+07FF)
                    else if cp < &HD800
                        mba.Push (92)           ' \
                        mba.Push (117)          ' u
                        m.baAppend (m.hex (cp))

                    ' Invalid chars (Unicode surrogate values) (U+0800 to U+DFFF)
                    else if cp < &HE000
                        octets = 1          ' Don't count these octets as valid (yet)
                        m.invalidChar (i, "Invalid Unicode code point (surrogate out-of-place)")

                    REM ' Valid Unicode 16-bit character (U+E000 to U+FFFD) [don't allow FFFE and FFFF in any plane]
                    REM else if cp < &HFFFE
                    ' Valid Unicode 16-bit character (U+E000 to U+FFFF)
                    else if cp < &H10000
                        mba.Push (92)           ' \
                        mba.Push (117)          ' u
                        m.baAppend (m.hex (cp))

                    ' Unicode surrogate pair (U+10000 to U+10FFFF)
                    else if cp < &H110000
                        REM ' Note that unicode values FFFE and FFFF are invalid in all planes
                        REM if cp Mod &H10000 < &HFFFE
                                ' Valid code point
                                cp20bits = cp - &H10000
                                cphigh10% = cp20bits / 1024                 ' >> 10
                                cplow10% = cp20bits - (cphigh10% * 1024)    ' << 10
                                m.baAppend ("\u" + m.hex (cphigh10% + &HD800) + "\u" + m.hex (cplow10% + &HDC00))
                        REM else
                            REM octets = 0          ' Don't count these octets as valid
                            REM m.invalidChar (i, "Invalid Unicode code point (U+xFFFE or U+xFFFF)")
                        REM endif

                    ' Invalid chars (> U+10FFFF)
                    else
                        octets = 1          ' Don't count these octets as valid
                        m.invalidChar (i, "Invalid Unicode code point (> U+10FFFF)")
                    endif

                endif

                ' Skip to next octet to be processed
                i = i + octets

            end while

            mba.Push (34)                   ' Closing quote
    end function

    ' Convert a string to an roByteArray for efficient processing
    this.formatString = function (mba as object, str as string)
            ba = CreateObject ("roByteArray")       ' TODO: Speed vs using global byte array and reset
            ba.FromAsciiString (str)                ' TODO: Test with zero-length string
            m.formatByteArrayAsString (mba, ba)
    end function

    ' Replace invalid octets with the replacement character. Recover from the next character
    this.invalidChar = function (i as integer, errorStr as string)
            m.baAppend (m.replacementChar)
            m.errorList.Push (errorStr + " at character position: " + i.ToStr ())   ' Store all errors
            m.invalidUtf8 = true
    end function

    ' Format an roDateTime in ISO 8601 format
    this.formatDateTime = function (j as object) as string
            year        = Right ("000"  + j.GetYear ().ToStr (), 4)
            month       = Right ("0"    + j.GetMonth ().ToStr (), 2)
            day         = Right ("0"    + j.GetDayOfMonth ().ToStr (), 2)
            hour        = Right ("0"    + j.GetHours ().ToStr (), 2)
            minute      = Right ("0"    + j.GetMinutes ().ToStr (), 2)
            second      = Right ("0"    + j.GetSeconds ().ToStr (), 2)
            return year + "-" + month + "-" + day + "T" + hour + ":" + minute + ":" + second
    end function

    this.PrintErrors = function ()
            for each errorItem in m.errorList
                print errorItem
            end for
    end function

    return this

end function
