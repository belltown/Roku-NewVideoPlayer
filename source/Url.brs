'*******************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'********************************************************************

' Dependencies:
'   _DEBUG_ON ()        Must be defined in as a Function returning True or False
'   _debug ()           in Utils.brs
'   _logEvent ()        in Utils.brs
'

'
' Read the contents of the specified path into a String
'
Function _getPathToString (path As String, timeout = 0 As Integer) As String
    If _urlIsFile (path)
        data = _getFileToString (path)
    Else
        data = _getUrlToString (path, timeout)
    End If
    Return data
End Function

'
' Read the contents of the specified path into a local file
'
Function _getPathToFile (destFile As String, srcPath As String, timeout = 0 As Integer) As Boolean
    If _urlIsFile (path)
        ret = _getFileToFile (destFile, srcPath)
    Else
        ret = _getUrlToFile (destFile, srcPath, timeout)
    End If
    Return ret
End Function

'
' Return True if the specified path is a local Roku file
'
Function _urlIsFile (path As String) As Boolean
    Return _urlIsPkg (path) Or _urlIsTmp (path) Or _urlIsCommon (path) Or _urlIsExt (path)
End Function

Function _urlIsPkg (path As String) As Boolean
    pkgDevice = "pkg:"
    Return LCase (Left (path, Len (pkgDevice))) = pkgDevice
End Function

Function _urlIsTmp (path As String) As Boolean
    tmpDevice = "tmp:"
    Return LCase (Left (path, Len (tmpDevice))) = tmpDevice
End Function

Function _urlIsCommon (path As String) As Boolean
    commonDevice = "common:"
    Return LCase (Left (path, Len (commonDevice))) = commonDevice
End Function

Function _urlIsExt (path As String) As Boolean
    extDevice = "ext"
    Return LCase (Left (path, Len (extDevice))) = extDevice And (Mid (path, 4, 1) >= "0" And Mid (path, 4, 1) <= "9") And Mid (path, 5, 1) = ":"
End Function

'
' Return the contents of a local file into a string
'
Function _getFileToString (fileName As String) As String
    Return ReadAsciiFile (fileName)
End Function

'
' Issue an HTTP GET request for the specified resource, returning as a String
'
Function _getUrlToString (url As String, timeout = 0 As Integer, headers = Invalid As Object) As String
    data = ""
    port = CreateObject ("roMessagePort")
    ut = CreateObject ("roUrlTransfer")
    ut.SetPort (port)
    ut.SetUrl (url)
    If headers <> Invalid
        ut.AddHeaders (headers)
    End If
    ut.EnableEncodings (True)
    If _urlIsHttps (url)
        ut.SetCertificatesFile ("common:/certs/ca-bundle.crt")
        ut.InitClientCertificates ()
    End If
    If ut.AsyncGetToString ()
        finished = False
        While Not finished
            msg = Wait (timeout, port)
            If msg = Invalid
                finished = True
                _debug ("_getUrlToString. AsyncGetToString timed out after " + timeout.ToStr () + " milliseconds")
                ut.AsyncCancel ()
            Else
                _logEvent ("_getUrlToString", msg)
                If Type (msg) = "roUrlEvent"
                    finished = True
                    If msg.GetInt () = 1
                        responseCode = msg.GetResponseCode ()
                        If responseCode < 0
                            _debug ("_getUrlToString. AsyncGetToString cUrl Error: " + responseCode.ToStr ())
                        Else If responseCode <> 200
                            _debug ("_getUrlToString. AsyncGetToString HTTP Error: " + responseCode.ToStr ())
                        Else
                            data = msg.GetString ()
                        End If
                    Else
                        _debug ("_getUrlToString. AsyncGetToString did not complete")
                        ut.AsyncCancel ()
                    End If
                End If
            End If
        End While
    Else
        _debug ("_getUrlToString. AsyncGetToString failed")
    End If
    Return data
End Function

'
' Read the contents of a local file into a file
'
Function _getFileToFile (destFileName As String, srcFileName As String) As Boolean
    Return CopyFile (srcFileName, destFileName)
End Function

'
' Issue an HTTP GET request for the specified resource, writing its contents to a file
'
Function _getUrlToFile (destFile As String, url As String, timeout = 0 As Integer, headers = Invalid As Object) As Boolean
    ret = False
    port = CreateObject ("roMessagePort")
    ut = CreateObject ("roUrlTransfer")
    ut.SetPort (port)
    ut.SetUrl (url)
    If headers <> Invalid
        ut.AddHeaders (headers)
    End If
    ut.EnableEncodings (True)
    If _urlIsHttps (url)
        ut.SetCertificatesFile ("common:/certs/ca-bundle.crt")
        ut.InitClientCertificates ()
    End If
    If ut.AsyncGetToFile (destFile)
        finished = False
        While Not finished
            msg = Wait (timeout, port)
            If msg = Invalid
                finished = True
                _debug ("_getUrlToFile. AsyncGetToFile timed out after " + timeout.ToStr () + " milliseconds")
                ut.AsyncCancel ()
            Else
                _logEvent ("_getUrlToFile", msg)
                If Type (msg) = "roUrlEvent"
                    finished = True
                    If msg.GetInt () = 1
                        responseCode = msg.GetResponseCode ()
                        If responseCode < 0
                            ' cUrl error
                            _debug ("_getUrlToFile. AsyncGetToFile cUrl error: " + responseCode.ToStr () + ". Failure Reason: " + msg.GetFailureReason ())
                        Else If responseCode <> 200
                            ' HTTP error
                            _debug ("_getUrlToFile. AsyncGetToFile HTTP error: " + responseCode.ToStr () + ". Failure Reason: " + msg.GetFailureReason ())
                        Else
                            ' Successfully retrieved the Url
                            ret = True
                        End If
                    Else
                        _debug ("_getUrlToFile. AsyncGetToFile did not complete")
                        ut.AsyncCancel ()
                    End If
                End If
            End If
        End While
    Else
        _debug ("_getUrlToFile. AsyncGetToFile failed")
    End If
    Return ret
End Function

' Return True if the url uses the secure "https" scheme
Function _urlIsHttps (url As String) As Boolean
    https = "https:"
    Return LCase (Left (url, Len (https))) = https
End Function

' Return True if the path name is a non-blank string
Function _urlIsValid (path As Dynamic) As Boolean
    Return (Type (GetInterface (Box (path), "ifString")) = "ifString") And (path <> "")
End Function

' Url-encode a query parameter
Function _urlEncode (queryParameter As String) As String
    Return CreateObject ("roUrlTransfer").Escape (queryParameter)
End Function
