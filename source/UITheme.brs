'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'********************************************************************

'
' Initialize the application-wide theme
'
Function uiThemeInit () As Void

    darkGrey    =   "#333333"
    white       =   "#b0b0b0"
    offWhite    =   "#8a8a8a"
    lightGrey   =   "#aaaaaa"
    mediumGrey  =   "#666666"
    darkWhite   =   "#525252"

    '
    ' Dark theme customizations for roPosterScreen and roSpringboardScreen
    '
    darkTheme   =   {

    ' No logos in this implementation ...
    REM OverhangPrimaryLogoSD:          "pkg:/images/OverhangPrimaryLogoSD.png"
    REM OverhangPrimaryLogoOffsetSD_X:  "55"
    REM OverhangPrimaryLogoOffsetSD_Y:  "34"
    REM OverhangPrimaryLogoHD:          "pkg:/images/OverhangPrimaryLogoHD.png"
    REM OverhangPrimaryLogoOffsetHD_X:  "123"
    REM OverhangPrimaryLogoOffsetHD_Y:  "0"

    FilterBannerSliceSD:                "pkg:/images/FilterSliceSD-1x38-1f1f1f.png"     ' solid, single color value of #1f1f1f
    FilterBannerSliceHD:                "pkg:/images/FilterSliceHD-1x60-1f1f1f.png"     ' solid, single color value of #1f1f1f
    OverhangSliceSD:                    "pkg:/images/OverhangSliceSD-1x83.png"          ' solid, single color value of #414a4c
    OverhangSliceHD:                    "pkg:/images/OverhangSliceHD-1x124.png"         ' solid, single color value of #414a4c
    GridScreenOverhangSliceSD:          "pkg:/images/OverhangSliceSD-1x83.png"          ' solid, single color value of #414a4c
    GridScreenOverhangSliceHD:          "pkg:/images/OverhangSliceHD-1x124.png"         ' solid, single color value of #414a4c
    GridScreenOverhangHeightSD:         "83"                                            ' Grid Screen overhang height (breadcrumb area)
    GridScreenOverhangHeightHD:         "124"                                           ' Grid Screen overhang height (breadcrumb area)
    BackgroundColor:                    darkGrey        ' Background color
    BreadcrumbTextLeft:                 "#777777"       ' Text color for leftmost breadcrumb (will vary with overhang slice color)
    BreadcrumbTextRight:                "#BBBBBB"       ' Text color for rightmost breadcrumb (will vary with overhang slice color)
    ButtonMenuHighlightText:            white           ' Text color for selected button on roSpringboardScreen
    ButtonMenuNormalText:               offWhite        ' Text color for non-selected button on roSpringboardScreen
    ButtonHighlightColor:               white           ' Text color for selected button on roParagraphScreen
    ButtonNormalColor:                  offWhite        ' Text color for non-selected button on roParagraphScreen
    PosterScreenLine1Text:              white           ' Text color for ShortDescriptionLine1 on roPosterScreen
    PosterScreenLine2Text:              offWhite        ' Text color for ShortDescriptionLine2 on roPosterScreen
    SpringboardTitleText:               lightGrey       ' Text color for Title on roSpringboardScreen
    SpringboardRuntimeColor:            mediumGrey      ' Text color for Length, ReleaseDate, and Rating on roSpringboardScreen
    SpringboardActorColor:              white           ' Text color for Actors on roSpringboardScreen
    SpringboardDirectorColor:           lightGrey       ' Text color for Director on roSpringboardScreen
    SpringboardDirectorLabelColor:      mediumGrey      ' Text color for Director label on roSpringboardScreen
    SpringboardDirectorText:            "director"      ' Text used as the Director label on roSpringboardScreen
    SpringboardGenreColor:              mediumGrey      ' Text color for Genres on roSpringboardScreen
    SpringboardSynopsisColor:           lightGrey       ' Text color for Description on roSpringboardScreen
    FilterBannerActiveColor:            white           ' Text color for the selected filter banner item when active
    FilterBannerInactiveColor:          white           ' Text color for the selected filter banner item when inactive
    FilterBannerSideColor:              darkWhite       ' Text color for the non-selected filter banner item
    }

    CreateObject ("roAppManager").SetTheme (darkTheme)

End Function
