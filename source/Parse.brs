'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' Read and parse an Xml document
' There are two types of Xml document supported: <categories> and <feed>
'
Function parseXmlDocument (xmlPath As String) As Object

    contentItem = {}

    ' Convert the Xml text into an roXMLElement component object
    xml = readXml (xmlPath)

    ' Return an empty content item if the Xml text parsing fails, otherwise parse the Xml document
    If Type (xml) = "roXMLElement"
        ' Get the Xml document's root element name (case-insensitive)
        xmlName = LCase (xml.GetName ())

        If xmlName = "categories" Or xmlName = "category"
            ' <categories> and <category> documents are handled identically
            contentItem = parseCategoryXml (xmlPath, xml)

        Else
            ' Assume we have a <feed> document
            contentItem = parseFeedXml (xml)
        End If
    End If

    Return contentItem

End Function

'
' Read an Xml document from a path (local file or remote url) and return an roXMLElement object
'
Function readXml (xmlPath As String) As Object

    ' Return an roXMLElement by parsing an Xml text file
    xml = CreateObject ("roXMLElement")

    ' Read the Xml document from either a local file or a remote url
    xmlString = _getPathToString (xmlPath)
    '_debug ("xmlString: " + xmlString)     ' un-comment to dump Xml file contents

    If xmlString <> ""
        If Not xml.Parse (xmlString)
            uiFatalError ("readXml", LINE_NUM, "Unable to parse Xml document: " + xmlPath)
            xml = Invalid
        End If
    Else
        uiFatalError ("readXml", LINE_NUM, "Unable to read Xml document: " + xmlPath)
    End If

    Return xml

End Function

'
' Parse a <categories> Xml document or <category> element, returning a content item that will contain a list of child content items.
' No separate data structures are used to represent the hierarchical content tree.
' All data is contained in Content Meta-Data objects.
' For a given node in the tree, the Content Meta-Data fields are filled in with whatever is needed to render a representation
' of that node on a screen (Title, Description, SDPosterUrl, etc.)
' Additional custom Content Meta-Data fields (prefixed with "xx") are used to contain the node's child nodes (xxChildContentList),
' and to indicate what type of nodes those children represent (xxFeedPath).
' <feed> elements may either be located within a category's Xml document, or read from an external Xml document (xxFeedPath contains its location).
' External Xml documents are not read until they need to be displayed. After that, they remain in memory (xxIsCached set to True).
'
Function parseCategoryXml (xmlPath As String, categoryXml As Object) As Object

    ' Return a single content item for the <categories> or <category> element that will include a list of any child items in xxChildContentList
    contentItem = {}

    ' A category may have a "feed" attribute, in which case it should not have any subordinate <category> or <categoryLeaf> elements
    feedPath            = _getXmlAttrString (categoryXml, "feed")   ' Our child content list corresponds to a <feed> element

    ' Get the immediate child nodes, ignoring anything other than <category> or <categoryLeaf> nodes
    categoryChildList   = categoryXml.GetNamedElementsCI ("category")
    leafChildList       = categoryXml.GetNamedElementsCI ("categoryLeaf")
    feedChildList       = categoryXml.GetNamedElementsCI ("feed")

    ' Recursively parse any child <category> elements or <categoryLeaf> elements
    ' There should be ONLY a "feed" attribute, or ONLY a single <feed> element, or ONLY <category> elements, or ONLY <categoryLeaf> elements

    ' A single <feed> element - feed located in the category's Xml file
    If feedChildList.Count () = 1 And feedPath = "" And categoryChildList.Count () = 0 And leafChildList.Count () = 0

        ' Get <category> attributes that will be applied to the in-line feed
        title               = _getXmlAttrString (categoryXml, "title")
        description         = _getXmlAttrString (categoryXml, "description")
        sdImg               = _getXmlAttrString (categoryXml, "sd_img")
        hdImg               = _getXmlAttrString (categoryXml, "hd_img")

        ' If one image field is missing, use the other
        If sdImg <> "" And hdImg = "" Then hdImg = sdImg
        If hdImg <> "" And sdImg = "" Then sdImg = hdImg

        ' Set up the Content Meta-Data
        contentItem.Title                   = title
        contentItem.Description             = description
        contentItem.ShortDescriptionLine1   = title
        contentItem.ShortDescriptionLine2   = description
        contentItem.SDPosterUrl             = sdImg
        contentItem.HDPosterUrl             = hdImg
        contentItem.xxChildContentList      = parseFeedXml (feedChildList [0])  ' The <feed> is located in the same document as the <category>
        contentItem.xxIsCached              = True
        contentItem.xxFeedType              = "feed"    ' Our child content list corresponds to a single <feed> element

    ' A "feed" attribute - feed located in a separate Xml file
    Else If feedChildList.Count () = 0 And feedPath <> "" And categoryChildList.Count () = 0 And leafChildList.Count () = 0

        ' Get <category> attributes that will be applied to the referenced feed
        title               = _getXmlAttrString (categoryXml, "title")
        description         = _getXmlAttrString (categoryXml, "description")
        sdImg               = _getXmlAttrString (categoryXml, "sd_img")
        hdImg               = _getXmlAttrString (categoryXml, "hd_img")

        ' If one image field is missing, use the other
        If sdImg <> "" And hdImg = "" Then hdImg = sdImg
        If hdImg <> "" And sdImg = "" Then sdImg = hdImg

        ' Set up this node's Content Meta-Data
        contentItem.Title                   = title
        contentItem.Description             = description
        contentItem.ShortDescriptionLine1   = title
        contentItem.ShortDescriptionLine2   = description
        contentItem.SDPosterUrl             = sdImg
        contentItem.HDPosterUrl             = hdImg

        ' Don't read the feed document until it is required to be displayed
        contentItem.xxIsCached              = False
        contentItem.xxFeedPath              = feedPath
        contentItem.xxFeedType              = "feed"    ' Our child content list corresponds to a single <feed> element

    ' Only <categories> or <category> elements
    Else If feedChildList.Count () = 0 And feedPath = "" And categoryChildList.Count () > 0 And leafChildList.Count () = 0

        childContentList = []

        ' Get <category> attributes
        title               = _getXmlAttrString (categoryXml, "title")
        description         = _getXmlAttrString (categoryXml, "description")
        sdImg               = _getXmlAttrString (categoryXml, "sd_img")
        hdImg               = _getXmlAttrString (categoryXml, "hd_img")

        ' If one image field is missing, use the other
        If sdImg <> "" And hdImg = "" Then hdImg = sdImg
        If hdImg <> "" And sdImg = "" Then sdImg = hdImg

        ' Recursively parse child <category> elements
        For Each child In categoryChildList
            childContentList.Push (parseCategoryXml (xmlPath, child))
        End For

        ' Set up the Content Meta-Data
        contentItem.Title                   = title
        contentItem.Description             = description
        contentItem.ShortDescriptionLine1   = title
        contentItem.ShortDescriptionLine2   = description
        contentItem.SDPosterUrl             = sdImg
        contentItem.HDPosterUrl             = hdImg

        ' Use a fixed-size array for the child content item list, and store in a custom content meta-data field
        contentItem.xxChildContentList      = CreateObject ("roArray", childContentList.Count (), False)

        For Each child In childContentList
            contentItem.xxChildContentList.Push (child)
        End For

        contentItem.xxIsCached = True
        contentItem.xxFeedType = "category"     ' The child content items are a list of <category> elements

    ' Only <categoryLeaf> elements
    Else If feedChildList.Count () = 0 And feedPath = "" And categoryChildList.Count () = 0 And leafChildList.Count () > 0

        ' Get <category> attributes - Used for content items for the roPosterScreen item representing this <category> element
        title               = _getXmlAttrString (categoryXml, "title")              ' Title (breadcrumb) and ShortDescriptionLine1
        description         = _getXmlAttrString (categoryXml, "description")        ' ShortDescriptionLine2
        sdImg               = _getXmlAttrString (categoryXml, "sd_img")             ' SDPosterUrl
        hdImg               = _getXmlAttrString (categoryXml, "hd_img")             ' HDPosterUrl

        ' If one image field is missing, use the other
        If sdImg <> "" And hdImg = "" Then hdImg = sdImg
        If hdImg <> "" And sdImg = "" Then sdImg = hdImg

        ' Set up the Content Meta-Data
        contentItem.Title                   = title                                 ' Used for breadcrumb
        contentItem.Description             = description                           ' Only used if SetListStyle ("flat-episodic..") used [Need to test]
        contentItem.ShortDescriptionLine1   = title                                 ' First line of poster screen description
        contentItem.ShortDescriptionLine2   = description                           ' Second line of poster screen description
        contentItem.SDPosterUrl             = sdImg                                 ' Poster screen image (SD)
        contentItem.HDPosterUrl             = hdImg                                 ' Poster screen image (HD)

        ' Parse child <categoryLeaf> elements
        leafList = []
        For Each child In leafChildList
            ' Get <categoryLeaf> attributes
            leafTitle                   = _getXmlAttrString (child, "title")        ' Used for roPosterScreen list name
            leafDescription             = _getXmlAttrString (child, "description")  ' Not currently used in the roPosterScreen with filter banner implementation
            leafFeedPath                = _getXmlAttrString (child, "feed")         ' Location of the <feed> element
            If leafFeedPath = ""
                uiFatalError ("parseCategoryXml", LINE_NUM, "A <categoryLeaf> has no feed attribute in Xml document: " + xmlPath)
            End If
            ' Don't read the leaf document until it is required to be displayed
            leafList.Push ({leafName: leafTitle, feedPath: leafFeedPath})
        End For

        ' Use fixed-length arrays of custom meta-data items for storing filter banner names and content item lists
        contentItem.xxChildNamesList        = CreateObject ("roArray", leafList.Count (), False)
        contentItem.xxChildContentList      = CreateObject ("roArray", leafList.Count (), False)

        ' Store names and content item lists in custom meta-data fields
        For Each leaf In leafList
            contentItem.xxChildNamesList.Push (leaf.leafName)
            ' Don't actually read in the leaf feed until the item is selected for display by the user
            contentItem.xxChildContentList.Push ({xxIsCached: False, xxFeedPath: leaf.feedPath})
        End For

        contentItem.xxIsCached = True       ' The <category> has been read into memory, even though its children have not
        contentItem.xxFeedType = "leaf"     ' The child content items are a list of <categoryLeaf> elements

    ' More than one <feed> element specified - invalid
    Else If feedChildList.Count () > 0
        contentItem.xxChildContentList = []
        contentItem.xxFeedType = "error"
        uiFatalError ("parseCategoryXml", LINE_NUM, "Cannot have more than one <feed> element for a <category> or <categoryleaf> in Xml document: " + xmlPath)

    ' <category> "feed" attribute specified with subordinate <category> or <categoryLeaf> elements - invalid
    Else If feedPath <> ""
        contentItem.xxChildContentList = []
        contentItem.xxFeedType = "error"
        uiFatalError ("parseCategoryXml", LINE_NUM, "Cannot have a <category> feed attribute with subordinate <category> or <categoryLeaf> elements in Xml document: " + xmlPath)

    ' Both <category> and <categoryLeaf> elements - invalid
    Else If categoryChildList.Count () > 0 And leafChildList.Count () > 0
        contentItem.xxChildContentList = []
        contentItem.xxFeedType = "error"
        uiFatalError ("parseCategoryXml", LINE_NUM, "Cannot have both <category> and <categoryLeaf> elements at the same level in Xml document: " + xmlPath)

    ' Neither <category> nor <categoryLeaf> elements - invalid
    Else
        contentItem.xxChildContentList = []
        contentItem.xxFeedType = "error"
        uiFatalError ("parseCategoryXml", LINE_NUM, "A <categories> or <category> is empty in Xml document: " + xmlPath)

    End If

    Return contentItem

End Function

'
' Parse a feed Xml document.
' The same function is called to parse a <feed> regardless of whether it is located
' in the same file as its category, or in a separate file.
' It's even possible for there to be no <categories> or <category> to display a <feed>;
' simply pass the feed file's path name into parseXmlDocument in Main ().
' Currently, only Roku-type feeds (as in the videoplayer SDK example) and RSS feeds
' are supported. Atom feeds are not currently supported and Atom meta-data elements are ignored.
' RSS feeds may have standard RSS 2.0 tags, MRSS extensions and iTunes extensions.
' The extensions that seem appropriate for a Roku implementation have been implemented.
'
Function parseFeedXml (xml As Object) As Object

    contentItem = {}

    '
    ' Determine the feed type:
    ' - Roku : Root element is <feed> with no "xmlns" attribute specified (supported)
    ' - Atom : Root element is <feed> with "xmlns:atom" attribute specified (not supported)
    ' - RSS/MRSS/iTunes : Root element is <rss> (supported)
    '

    rootElementName = LCase (xml.GetName ())

    If rootElementName = "rss"
        ' RSS/MRSS/iTunes feed [may also have atom: tags, which we don't currently support]
        contentItem = getRssContent (xml)

    Else If rootElementName = "feed"

        attrAA = xml.GetAttributes ()
        hasXmlns = False
        For Each key In attrAA
            xmlns = "xmlns"
            If LCase (Left (key, Len (xmlns))) = xmlns
                hasXmlns = True
            End If
        End For

        If Not hasXmlns
            ' Roku feed
            contentItem = getRokuContent (xml)

        Else If xml.HasAttribute ("xmlns:atom")
            ' Atom Feed
            contentItem = getAtomContent (xml)

        Else
            ' Unsupported feed xmlns
            uiSoftError ("parseFeedXml", LINE_NUM, "Unsupported Feed Type: Feed: " + rootElementName + ". xmlns: " + xmlNs)
        End If

    Else
        ' Unsupported feed type
        uiSoftError ("parseFeedXml", LINE_NUM, "Unsupported Feed Type: " + rootElementName)
    End If

    Return contentItem

End Function
