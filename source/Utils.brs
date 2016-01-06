'*******************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'********************************************************************

' Dependencies:
'   _DEBUG_ON ()        Must be defined as a Function returning True or False
'   FormatJson.brs      Required if the legacy code is included in _setBoookmark () and _clearBookmark ()
'

'
' Produce a quoted string value from a string value
'
Function _quote (s As String) As String
    Return Chr (34) + s + Chr (34)
End Function

'
' Return True if this device is running in HD mode, otherwise False
'
Function _isHD () As Boolean
    Return CreateObject ("roDeviceInfo").GetDisplayType () = "HDTV"
End Function

'
' ifDeviceInfo.GetVersion () returns the version number of the Roku firmware.
' This is a 13-character string, e.g. "034.08E01185A".
' The 3rd through 6th characters are the major/minor version number ("4.08"), and the 9th through 12th are the build number ("1185").
' Parse the Roku device info version string and return as integers.
'
Function _getRokuVersion () As Object

    vsn = {Major: 0, Minor: 0, Build: 0, IsLegacy: True}

    diVsn = CreateObject ("roDeviceInfo").GetVersion ()
    majMin = (Mid (diVsn, 3, 4)).Tokenize (".")
    If majMin.Count () > 0 Then vsn.Major = majMin [0].ToInt ()
    If majMin.Count () > 1 Then vsn.Minor = majMin [1].ToInt ()
    vsn.Build = (Mid (diVsn, 9, 4)).ToInt ()
    vsn.IsLegacy = vsn.Major < 5

    Return vsn

End Function

Function _isLegacy () As Boolean
    Return _getRokuVersion ().IsLegacy
End Function

'
' Retrieve the value of the bookmark having the specified key
'
Function _getBookmark (key As String) As Dynamic

    value = 0

    ' The key identifies the item being bookmarked (e.g. ContentId).
    ' If the key is blank then don't attempt to read a bookmark.
    If key <> ""
        ' All bookmarks are contained in the NVP-Bookmarks registry section
        rs = CreateObject ("roRegistrySection", "NVP-Bookmarks")
        ' Make sure we can read the registry section, otherwise we'd crash when attempting to read keys from the section
        If Type (rs) <> "roRegistrySection"
            _debug ("_getBookmark. Unable to create roRegistrySection")
        Else
            ' Read the current bookmark list from the Bookmark-List key stored in the registry, converting to a JSON array
            bookmarkListString = rs.Read ("Bookmark-List")
            If bookmarkListString <> ""
                bookmarkListJson = ParseJSON (bookmarkListString)
                ' Check that we have a valid bookmark JSON list
                If Type (bookmarkListJson) = "roArray"
                    index = 0
                    ' Iterate through each existing bookmark until we find the one being read
                    While index < bookmarkListJson.Count ()
                        bookmarkValue = bookmarkListJson [index].Lookup (key)
                        If bookmarkValue <> Invalid
                            ' We've found the bookmark
                            value = bookmarkValue
                            Exit While
                        End If
                        index = index + 1
                    End While
                End If
            End If
        End If
    End If

    Return value

End Function

'
' Store the bookmark value for the specified item key in the registry.
' All bookmarks are stored in the "NVP-Bookmarks" registry section.
' The list of bookmarks is stored as a JSON-encoded string value in the "Bookmark-List" registry key.
' Limit the number of bookmarks stored.
' Each time a bookmark value is stored, it is stored at the head of the list, the remaining bookmarks
' are added after the new value, any bookmarks in excess of the limit being discarded.
'
' Note - this is not a particularly efficient implementation, but should be adequate if the
' position notification interval is set to a reasonable value and the number of bookmarks stored is constrained.
'
Function _setBookmark (key As String, value As Dynamic) As Void

    MAX_BOOKMARKS = 10      ' Set the maximum number of bookmarks here

    ' The key identifies the item being bookmarked (e.g. ContentId)
    ' If the key is blank then don't attempt to set a bookmark
    If key <> ""
        ' All bookmarks are contained in the NVP-Bookmarks registry section
        rs = CreateObject ("roRegistrySection", "NVP-Bookmarks")
        ' Make sure we can read the registry section, otherwise we'd crash when attempting to read keys from the section
        If Type (rs) <> "roRegistrySection"
            _debug ("_setBookmark. Unable to create roRegistrySection")
        Else
            ' Construct a new list of bookmarks, up to the maximum limit we impose
            bookmarkList = []
            ' Add the new key/value pair as the first item in the new bookmark list
            aa = {}
            aa.AddReplace (key, value)
            bookmarkList.Push (aa)
            ' Read the current bookmark list from the Bookmark-List key stored in the registry, converting to a JSON array
            bookmarkListString = rs.Read ("Bookmark-List")
            If bookmarkListString <> ""
                bookmarkListJson = ParseJSON (bookmarkListString)
                ' If there is not an existing bookmark list, or if it is not a valid Json array then we'll be creating a new list with the new key
                If Type (bookmarkListJson) = "roArray"
                    index = 0
                    ' Iterate through each existing bookmark, up to our limit
                    While index < MAX_BOOKMARKS And index < bookmarkListJson.Count ()
                        ' We've already added the new bookmark to our new list, so don't add it again from the registry
                        If bookmarkListJson [index].Lookup (key) = Invalid
                            ' This is not the key we already added, so add it to the new list
                            bookmarkList.Push (bookmarkListJson [index])
                        End If
                        index = index + 1
                    End While
                End If
            End If

            ' Convert the bookmark list (array) to a JSON string and write back into the registry, replacing any existing list
            If Not _getRokuVersion ().IsLegacy      ' FormatJSON () is not implemented in legacy firmware versions
                If Not rs.Write ("Bookmark-List", FormatJSON (bookmarkList))
                    _debug ("_setBookmark. Unable to write to registry")
                ' Commit the registry write
                Else If Not rs.Flush ()
                    _debug ("_setBookmark. Unable to flush registry")
                End If
            ' *** Legacy Code - no longer needed with post-3.1 firmware
            Else
                jsonFormatter = createJsonFormatter ()
                If Not rs.Write ("Bookmark-List", jsonFormatter.FormatJson (bookmarkList))
                    _debug ("_setBookmark. Unable to write to registry")
                ' Commit the registry write
                Else If Not rs.Flush ()
                    _debug ("_setBookmark. Unable to flush registry")
                End If
            ' *** End Legacy Code
            End If
        End If

    End If
End Function

'
' Delete the bookmark with the specified key
'
Function _clearBookmark (key As String) As Void

    ' The key identifies the item being bookmarked
    ' If the key is blank then don't attempt to set a bookmark
    If key <> ""
        ' All bookmarks are contained in the NVP-Bookmarks registry section
        rs = CreateObject ("roRegistrySection", "NVP-Bookmarks")
        ' Make sure we can read the registry section, otherwise we'd crash when attempting to read keys from the section
        If Type (rs) <> "roRegistrySection"
            _debug ("_clearBookmark. Unable to create roRegistrySection")
        Else
            ' Construct a new list of bookmarks
            bookmarkList = []
            ' Read the current bookmark list from the Bookmark-List key stored in the registry, converting to a JSON array
            bookmarkListString = rs.Read ("Bookmark-List")
            If bookmarkListString <> ""
                bookmarkListJson = ParseJSON (bookmarkListString)
                ' Check if a valid bookmark list exists
                If Type (bookmarkListJson) = "roArray"
                    index = 0
                    ' Iterate through each existing bookmark
                    While index < bookmarkListJson.Count ()
                        ' If this is not the key being deleted, add it to the new list
                        If bookmarkListJson [index].Lookup (key) = Invalid
                            ' Add key to the new list
                            bookmarkList.Push (bookmarkListJson [index])
                        End If
                        index = index + 1
                    End While
                End If
            End If

            ' Convert the bookmark list (array) to a JSON string and write back into the registry, replacing any existing list
            If Not _getRokuVersion ().IsLegacy      ' FormatJSON () is not implemented in legacy firmware versions
                If Not rs.Write ("Bookmark-List", FormatJSON (bookmarkList))
                    _debug ("_clearBookmark. Unable to write to registry")
                ' Commit the registry write
                Else If Not rs.Flush ()
                    _debug ("_clearBookmark. Unable to flush registry")
                End If
            ' *** Legacy Code - no longer needed with post-3.1 firmware
            Else
                jsonFormatter = createJsonFormatter ()
                If Not rs.Write ("Bookmark-List", jsonFormatter.FormatJson (bookmarkList))
                    _debug ("_setBookmark. Unable to write to registry")
                ' Commit the registry write
                Else If Not rs.Flush ()
                    _debug ("_setBookmark. Unable to flush registry")
                End If
            ' *** End Legacy Code
            End If
        End If

    End If
End Function

'
' Print the contents of a registry section
'
Function _dumpRegistrySection (section As String) As Void
    _debug ("    Dumping Registry Section: " + section)
    rs = CreateObject ("roRegistrySection", section)
    For Each key In rs.GetKeyList ()
        _debug ("        " + key + ": " + rs.Read (key))
    End For
End Function

'
' Print the contents of the registry
'
Function _dumpRegistry (sectionName = "" As String) As Void
    _debug ("Dumping Registry:")
    If sectionName = ""
        r = CreateObject ("roRegistry")
        For Each section In r.GetSectionList ()
            _dumpRegistrySection (section)
        End For
    Else
        _dumpRegistrySection (sectionName)
    End If
End Function

'
' Debugging tool only - wipes the registry clean, deleting all sections
'
Function _wipeRegistry () As Void
    reg = CreateObject ("roRegistry")
    For Each section In reg.GetSectionList ()
        If reg.Delete (section)
            _debug ("wipeRegistry. Deleted section: " + section)
        Else
            _debug ("wipeRegistry. Failed to delete section: " + section)
        End If
    End For
    reg.Flush ()
End Function

'
' Construct a hash value from a string.
' Used to create a pseudo-unique ContentID if needed.
'
Function _hash (input As String) As String
    hash = ""
    If input <> ""
        ba = CreateObject ("roByteArray")
        ev = CreateObject ("roEVPDigest")
        ev.Setup ("md5")
        ba.FromAsciiString (input)
        hash = ev.Process (ba)
    End If
    Return hash
End Function

'==================================================================
'                          General Utilities
'==================================================================

'
' Determine whether an item is a valid string type
'
Function _isString (item As Dynamic) As Boolean
    Return LCase (Type (item)) = "rostring" Or LCase (Type (item)) = "string"
End Function


'
' Determine whether an item is a valid array type
'
Function _isArray (item As Dynamic) As Boolean
    Return LCase (Type (item)) = "roarray" Or LCase (Type (item)) = "rolist"
End Function

'
' Replace entity references with their character equivalents.
' Used to deal with badly-encoded Xml documents.
'
Function _xmlEntityDecode (data As String) As String
    result = data

    re = CreateObject ("roRegex", "&amp;", "&")
    result = re.ReplaceAll (result, "&")

    re = CreateObject ("roRegex", "&(#039;|#x27;|#8217;|#x2019;|rsquo;|#8216;|#x2018;|lsquo;)", "i")
    result = re.ReplaceAll (result, "'")

    re = CreateObject ("roRegex", "&(#34;|#x22;|quot;|#8217;|#8220;|#x201c;|ldquo;|#8221;|#x201d;|rdquo;)", "i")
    result = re.ReplaceAll (result, Chr (34))

    re = CreateObject ("roRegex", "&\w+;", "")
    result = re.ReplaceAll (result, "")

    Return result
End Function

'
' Remove html tags from a string
'
Function _stripHtmlTags (data As String) As String
    result = data

    re = CreateObject ("roRegex", "<[^>]*>", "")
    result = re.ReplaceAll (data, "")

    Return result
End Function
'==================================================================
'                          Xml Utilities
'==================================================================

'
' Get the string value of an Xml attribute
'
Function _getXmlAttrString (xml As Dynamic, attr As String, defaultValue = "" As String) As String
    returnValue = defaultValue
    If GetInterface (xml, "ifXMLList") <> Invalid Or GetInterface (xml, "ifXMLElement") <> Invalid
        attributes = xml.GetAttributes ()
        If GetInterface (attributes, "ifAssociativeArray") <> Invalid
            value = attributes.LookupCI (attr)
            If value <> Invalid
                returnValue = value.Trim ()
            End If
        End If
    End If
    Return returnValue
End Function

'
' Get the string value of an Xml attribute
'
Function _getXmlAttrInteger (xml As Dynamic, attr As String, defaultValue = 0 As Integer) As Integer
    returnValue = defaultValue
    If GetInterface (xml, "ifXMLList") <> Invalid Or GetInterface (xml, "ifXMLElement") <> Invalid
        attributes = xml.GetAttributes ()
        If GetInterface (attributes, "ifAssociativeArray") <> Invalid
            value = attributes.LookupCI (attr)
            If value <> Invalid
                returnValue = value.Trim ().ToInt ()
            End If
        End If
    End If
    Return returnValue
End Function

'
' Get the string value of an Xml element
'
Function _getXmlString (xml As Dynamic, fieldName As String, defaultValue = "" As String) As String
    returnValue = defaultValue
    ' Ensure we have a valid Xml element or list
    If GetInterface (xml, "ifXMLList") <> Invalid Or GetInterface (xml, "ifXMLElement") <> Invalid
        ' Extract the specifed field by name (case-insensitive)
        xmlElementList = xml.GetNamedElementsCI (fieldName)
        ' If more than one item with the specified name, choose the first one
        If xmlElementList.Count () > 0
            returnValue = xmlElementList [0].GetText ().Trim ()
        End If
    End If
    Return returnValue
End Function

'
' Get the integer value of an Xml element
'
Function _getXmlInteger (xml As Dynamic, fieldName As String, defaultValue = 0 As Integer) As Integer
    returnValue = defaultValue
    ' Ensure we have a valid Xml element or list
    If GetInterface (xml, "ifXMLList") <> Invalid Or GetInterface (xml, "ifXMLElement") <> Invalid
        ' Extract the specifed field by name (case-insensitive)
        xmlElementList = xml.GetNamedElementsCI (fieldName)
        ' If more than one item with the specified name, choose the first one
        If xmlElementList.Count () > 0
            returnValue = xmlElementList [0].GetText ().Trim ().ToInt ()
        End If
    End If
    Return returnValue
End Function

'
' Get the boolean value of an Xml element
'
Function _getXmlBoolean (xml As Dynamic, fieldName As String, defaultValue = False As Boolean) As Boolean
    returnValue = defaultValue
    ' Ensure we have a valid Xml element or list
    If GetInterface (xml, "ifXMLList") <> Invalid Or GetInterface (xml, "ifXMLElement") <> Invalid
        ' Extract the specifed field by name (case-insensitive)
        xmlElementList = xml.GetNamedElementsCI (fieldName)
        ' If more than one item with the specified name, choose the first one
        If xmlElementList.Count () > 0
            value = LCase (xmlElementList [0].GetText ().Trim ())
            returnValue = (value = "true" Or value = "yes" Or value = "1")
        End If
    End If
    Return returnValue
End Function

'
' Format a time string used in debug event logging
'
Function _timeStr (dtIn = Invalid As Object) As String

    dt = CreateObject ("roDateTime")

    If dtIn = Invalid
        dt.Mark ()
    Else
        dt = dtIn
    End If

    dt.ToLocalTime ()

    str = ""
    str = str + Right ("0"  + dt.GetHours ().ToStr (), 2)           + ":"
    str = str + Right ("0"  + dt.GetMinutes ().ToStr (), 2)         + ":"
    str = str + Right ("0"  + dt.GetSeconds ().ToStr (), 2)         + "."
    str = str + Right ("00" + dt.GetMilliseconds ().ToStr (), 3)    + "   "

    Return str

End Function

'
' Get the string value of a remote key code
'
Function _remoteKeyStr (key% As Integer) As String
    key$ = "Unknown Key"
    keyAA = {}
    keyAA ["0"]     = "Back Key Pressed"
    keyAA ["2"]     = "Up Key Pressed"
    keyAA ["3"]     = "Down Key Pressed"
    keyAA ["4"]     = "Left Key Pressed"
    keyAA ["5"]     = "Right Key Pressed"
    keyAA ["6"]     = "Select Key Pressed"
    keyAA ["7"]     = "Instant Replay Key Pressed"
    keyAA ["8"]     = "Rewind Key Pressed"
    keyAA ["9"]     = "Fast Forward Key Pressed"
    keyAA ["10"]    = "Info Key Pressed"
    keyAA ["13"]    = "Play Key Pressed"
    keyAA ["100"]   = "Back Key Released"
    keyAA ["102"]   = "Up Key Released"
    keyAA ["103"]   = "Down Key Released"
    keyAA ["104"]   = "Left Key Released"
    keyAA ["105"]   = "Right Key Released"
    keyAA ["106"]   = "Select Key Released"
    keyAA ["107"]   = "Instant Replay Key Released"
    keyAA ["108"]   = "Rewind Key Released"
    keyAA ["109"]   = "Fast Forward Key Released"
    keyAA ["110"]   = "Info Key Released"
    keyAA ["113"]   = "Play Key Released"
    keyAA ["8364"]  = "Euro Key Pressed"
    keyAA ["8464"]  = "Euro Key Released"
    keyAA ["9200"]  = "Alarm Clock Key Pressed"
    keyAA ["9300"]  = "Alarm Clock Key Released"
    keyStrLookup = keyAA.Lookup (key%.ToStr ())
    If keyStrLookup <> Invalid Then key$ = keyStrLookup
    Return key$
End Function

'
' Log events
'
Function _logEvent (proc As String, msg As Dynamic) As Void
    If _DEBUG_ON ()
        If msg = Invalid
            evType = "Invalid"
            _debug (proc + ". Invalid")
        Else
            evStr = ""
            evType = Type (msg)
            If evType = "roTextureRequestEvent"
                id = msg.GetId ()
                stateList = ["Requested", "Downloading", "Downloaded", "Ready", "Failed", "Cancelled"]
                state = msg.GetState ()
                If state >= 0 And state < stateList.Count () Then stateStr = stateList [state] Else stateStr = "Unknown state"
                uri = msg.getURI ()
                evStr = ". Id: " + id.ToStr () + ". State:" + stateStr + ". Uri: " + uri
                _debug (proc + ". " + evType + evStr)
            Else If evType = "roAudioPlayerEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsListItemSelected ()
                    evStr = "isListItemSelected. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsStatusMessage ()
                    evStr = "isStatusMessage. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsRequestSucceeded ()
                    evStr = "isRequestSucceeded. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsRequestFailed ()
                    evStr = "isRequestFailed. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsFullResult ()
                    evStr = "isFullResult"
                Else If msg.IsPartialResult ()
                    evStr = "isPartialResult"
                Else If msg.IsPaused ()
                    evStr = "isPaused"
                Else If msg.IsResumed ()
                    evStr = "isResumed"
                Else If msg.IsRequestInterrupted () ' Undocumented event
                    evStr = "IsRequestInterrupted: Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsStreamStarted ()      ' Undocumented event
                    evStr = "isStreamStarted. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsFormatDetected ()     ' Undocumented event
                    evStr = "isFormatDetected. Index: " + msg.GetIndex ().ToStr ()
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roVideoScreenEvent" Or evType = "roVideoPlayerEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsStreamStarted ()
                    info = msg.GetInfo ()
                    If info.IsUnderrun Then underrun = "true" Else underrun = "false"
                    evStr = "isStreamStarted. Index: " + msg.GetIndex ().ToStr ()
                    evStr = evStr + ". Url: " + info.Url
                    evStr = evStr + ". StreamBitrate: " + StrI (info.StreamBitrate / 1000).Trim ()
                    evStr = evStr + ". MeasuredBitrate: " + info.MeasuredBitrate.ToStr ()
                    evStr = evStr + ". IsUnderrun: " + underrun
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsPlaybackPosition ()
                    evStr = "isPlaybackPosition. Index: " + msg.GetIndex ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsRequestFailed ()
                    index = msg.GetIndex ()
                    info = msg.GetInfo ()
                    evStr = "isRequestFailed. Message: " + msg.GetMessage () + " Index: " + index.ToStr ()
                    If index <= 0 And index >= -5
                        failMessage = [ "Network error : server down or unresponsive, server is unreachable, network setup problem on the client",
                                        "HTTP error: malformed headers or HTTP error result",
                                        "Connection timed out",
                                        "Unknown error",
                                        "Empty list; no streams were specified to play",
                                        "Media error; the media format is unknown or unsupported" ][-index]
                        evStr = evStr + " [" + failMessage + "]"
                    End If
                    If info <> Invalid  ' fw 3.1 does not return 'info'
                        If info.LookupCI ("Url") <> Invalid Then evStr = evStr + ". Url: " + info.Url
                        If info.LookupCI ("StreamBitrate") <> Invalid Then evStr = evStr + ". StreamBitrate: " + info.StreamBitrate.ToStr ()
                        If info.LookupCI ("MeasuredBitrate") <> Invalid Then evStr = evStr + ". MeasuredBitrate: " + info.MeasuredBitrate.ToStr ()
                    End If
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsStatusMessage ()
                    evStr = "isStatusMessage. Message: " + msg.GetMessage ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsFullResult ()
                    evStr = "isFullResult"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsPartialResult ()
                    evStr = "isPartialResult"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsPaused ()
                    evStr = "isPaused"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsResumed ()
                    evStr = "isResumed"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If msg.IsStreamSegmentInfo ()
                    info = msg.GetInfo ()
                    evStr = "isStreamSegmentInfo. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                    _debug ("StreamBandwidth:  " + info.StreamBandwidth.ToStr (), ">     ")
                    _debug ("Sequence:         " + info.Sequence.ToStr (), ">     ")
                    _debug ("SegUrl:           " + info.SegUrl, ">     ")
                    _debug ("SegStartTime:     " + info.SegStartTime.ToStr (), ">     ")
                Else If Not _isLegacy () And msg.IsSegmentDownloadStarted ()    ' Undocumented event
                    info = msg.GetInfo ()
                    evStr = "isSegmentDownloadStarted. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                    _debug ("Sequence:         " + info.Sequence.ToStr (), ">     ")
                    _debug ("SegBitrate:       " + info.SegBitrate.ToStr (), ">     ")
                    _debug ("StartTime:        " + info.StartTime.ToStr (), ">     ")
                    _debug ("EndTime:          " + info.EndTime.ToStr (), ">     ")
                Else If Not _isLegacy () And msg.IsDownloadSegmentInfo ()   ' Undocumented event
                    info = msg.GetInfo ()
                    evStr = "isDownloadSegmentInfo. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                    _debug ("Sequence:         " + info.Sequence.ToStr (), ">     ")
                    _debug ("Status:           " + info.Status.ToStr (), ">     ")
                    _debug ("SegBitrate:       " + info.SegBitrate.ToStr (), ">     ")
                    _debug ("DownloadDuration: " + info.DownloadDuration.ToStr (), ">     ")
                    _debug ("SegUrl:           " + info.SegUrl, ">     ")
                    _debug ("SegSize:          " + info.SegSize.ToStr (), ">     ")
                    _debug ("BufferSize:       " + info.BufferSize.ToStr (), ">     ")
                    _debug ("BufferLevel:      " + info.BufferLevel.ToStr (), ">     ")
                    _debug ("SegType:          " + info.SegType.ToStr (), ">     ")
                Else If msg.IsListItemSelected ()       ' Undocumented event for this event type
                    evStr = "isListItemSelected ???. Index: " + msg.GetIndex ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If Not _isLegacy () And msg.IsTimedMetaData ()
                    index = msg.GetIndex ()
                    info = msg.GetInfo ()
                    evStr = "isTimedMetaData. Message: " + msg.GetMessage () + " PTS Timecode: " + index.ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else If Not _isLegacy () And msg.IsCaptionModeChanged ()
                    index = msg.GetIndex ()
                    evStr = "isCaptionModeChanged. Message: " + msg.GetMessage () + ". Index: " + index.ToStr ()
                    If index = 0 Then evStr = evStr + " [Off]"
                    If index = 1 Then evStr = evStr + " [On]"
                    If index = 2 Then evStr = evStr + " [Instant replay]"
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                    _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
                End If
            Else If evType = "roSystemLogEvent"
                msgType = msg.GetType ().ToStr ()
                info = msg.GetInfo ()
                _debug (proc + ". " + evType + " [" + msgType + "]-" + "LogType=" + info.LogType + ". Datetime: " + _timeStr (info.Datetime))
                evStr = ""
                If info.LogType = "http.error" Or info.LogType = "http.connect"
                    _debug ("Url:              " + info.Url, ">     ")
                    _debug ("Status:           " + info.Status, ">     ")
                    _debug ("HttpCode:         " + info.HttpCode.ToStr (), ">     ")
                    _debug ("Method:           " + info.Method, ">     ")
                    _debug ("TargetIp:         " + info.TargetIp, ">     ")
                    _debug ("OrigUrl:          " + info.OrigUrl, ">     ")
                Else If info.LogType = "bandwidth.minute"
                    _debug ("Bandwidth: " + info.bandwidth.ToStr (), ">     ")
                Else
                    ' Unknown log type
                    _debug ("(unknown log type)", ">     ")
                End If
            Else If evType = "roPosterScreenEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsListFocused ()
                    evStr = "isListFocused. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsListSelected ()
                    evStr = "isListSelected. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsListItemFocused ()
                    evStr = "isListItemFocused. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsListItemSelected ()
                    evStr = "isListItemSelected. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsAdSelected ()
                    evStr = "isAdSelected"
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else If msg.IsListItemInfo ()
                    evStr = "isListItemInfo. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsRemoteKeyPressed ()
                    evStr = "isRemoteKeyPressed. Index: " + msg.GetIndex ().ToStr () + " [" + _remoteKeyStr (msg.GetIndex ()) + "]"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roGridScreenEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsListItemFocused ()
                    evStr = "isListItemFocused. Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                Else If msg.IsListItemSelected ()
                    evStr = "isListItemSelected. Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else If msg.IsRemoteKeyPressed ()
                    evStr = "isRemoteKeyPressed. Index: " + msg.GetIndex ().ToStr () + " [" + _remoteKeyStr (msg.GetIndex ()) + "]"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + ". Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roSpringboardScreenEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsButtonPressed ()
                    evStr = "isButtonPressed. Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                Else If msg.IsRemoteKeyPressed ()
                    evStr = "isRemoteKeyPressed. Index: " + msg.GetIndex ().ToStr () + " [" + _remoteKeyStr (msg.GetIndex ()) + "]"
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else If msg.IsButtonInfo ()
                    evStr = "isButtonInfo. Index: " + msg.GetIndex ().ToStr ()
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roUrlEvent"
                evStr = ""
                evStr = evStr + ". Int: " + msg.GetInt ().ToStr ()
                evStr = evStr + ". ResponseCode: " + msg.GetResponseCode ().ToStr ()
                evStr = evStr + ". FailureReason: " + msg.GetFailureReason ()
                evStr = evStr + ". SourceIdentity: " + msg.GetSourceIdentity ().ToStr ()
                evStr = evStr + ". TargetIpAddress: " + msg.GetTargetIpAddress ()
                _debug (proc + ". " + evType + evStr)
            Else If evType = "roUniversalControlEvent"
                key = msg.GetInt ()
                _debug (proc + ". " + evType + ". Int: " + key.ToStr () +  " [" + _remoteKeyStr (key) + "]")
            Else If evType = "roParagraphScreenEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsButtonPressed ()
                    evStr = "isButtonPressed. Index: " + msg.GetIndex ().ToStr () + ". Data: " + msg.GetData ().ToStr ()
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roImageCanvasEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsRemoteKeyPressed ()
                    evStr = "isRemoteKeyPressed. Index: " + msg.GetIndex ().ToStr () + " [" + _remoteKeyStr (msg.GetIndex ()) + "]"
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roMessageDialogEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsButtonPressed ()
                    evStr = "isButtonPressed. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsButtonInfo ()
                    evStr = "isButtonInfo. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            Else If evType = "roListScreenEvent"
                msgType = msg.GetType ().ToStr ()
                If msg.IsScreenClosed ()
                    evStr = "isScreenClosed"
                Else If msg.IsListItemFocused ()
                    evStr = "isListItemFocused. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsListItemSelected ()
                    evStr = "isListItemSelected. Index: " + msg.GetIndex ().ToStr ()
                Else If msg.IsRemoteKeyPressed ()
                    evStr = "isRemoteKeyPressed. Index: " + msg.GetIndex ().ToStr () + " [" + _remoteKeyStr (msg.GetIndex ()) + "]"
                Else
                    evStr = "Unknown. Message: " + msg.GetMessage () + " Index: " + msg.GetIndex ().ToStr ()
                End If
                _debug (proc + ". " + evType + " [" + msgType + "]-" + evStr)
            '
            ' Add more event types here as needed ...
            '

            Else
                _debug (proc + ". Unexpected Event: " + evType)
            End If
        End If
    End If
End Function

'
' Log _debug messages to the console. Function _DEBUG_ON () must be defined, and must return True (debug logging on) or False (debug logging off)
'
Function _debug (message As String, indentString = "" As String) As Void
    If _DEBUG_ON ()
        dt = CreateObject ("roDateTime")
        dt.ToLocalTime ()
        hh  = Right ("0"    + dt.GetHours ().ToStr (), 2)
        mm  = Right ("0"    + dt.GetMinutes ().ToStr (), 2)
        ss  = Right ("0"    + dt.GetSeconds ().ToStr (), 2)
        mmm = Right ("00"   + dt.GetMilliseconds ().ToStr (), 3)
        Print hh; ":"; mm; ":"; ss; "."; mmm; "  "; indentString; message
    End If
End Function
