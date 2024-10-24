Option Explicit On

Function AttributeValue() As Variant

    Dim retval As Variant

    'ENTER YOUR CALCULATION HERE!!
    retval = ""

    Dim straightEdgework As String
    Dim arrayEW() As String
    Dim ew As String
    Dim keyPairLinIN() As String
    Dim linealIN As Single
    Dim linealINprePost As Single
    Dim LITE As String
    Dim preEdge As Boolean
    Dim postEdge As Boolean
    Dim i As Integer
    Dim j As Integer
    Dim numLayers As Integer
    Dim numILayers As Integer
    Dim sgpIL As Boolean

    linealIN = 0
    linealINprePost = 0
    preEdge = False
    postEdge = False
    sgpIL = False

    straightEdgework = Attributes("EW-STRAIGHT").value
    LITE = Attributes("LITE").value

    If straightEdgework <> "" And IsNumeric(RIGHT(GroupCode("LITE " & LITE & " GLASS"), 1)) Then

        'loop through interlayers to see if there is film. Always pre-lami edge glass with film interlayers
        numLayers = RIGHT(GroupCode("LITE " & LITE & " GLASS"), 1)
        For i = 1 To numLayers
            If i < numLayers Then
                numILayers = LEFT(GroupCode("LITE " & LITE & "." & i & " INTERLAYERS"), 1)

                If OptionExists("SHATOP", "LITE " & LITE & "." & i & " OPTION") Then
                    postEdge = True
                    Exit For
                End If

                For j = 1 To numILayers
                    If GroupCode("LITE " & LITE & "." & i & " IL" & j & " TYPE") = "ILPRT" Or GroupCode("LITE " & LITE & "." & i & " IL" & j & " TYPE") = "ILFAB" Or GroupCode("LITE " & LITE & "." & i & " IL" & j & " TYPE") = "ILNAT" Or GroupCode("LITE " & LITE & "." & i & " IL" & j & " TYPE") = "ILSGP" Then
                        If GroupCode("LITE " & LITE & "." & i & " IL" & j) = "IMSCIPI" And GroupCode("LITE " & LITE & "." & i & " PROCESS") = "AN" Then
                            postEdge = True
                        Else
                            preEdge = True
                        End If
                        If GroupCode("LITE " & LITE & "." & i & " IL" & j & " TYPE") = "ILSGP" Then
                        	sgpIL = True
                        End If
                        Exit For
                    End If
                Next 'j
            End If
        Next 'i

        If postEdge Or ((Attributes("ANNLAMI").value = 1 Or InStr(straightEdgework, "EFGPO") > 0) And Attributes("CP-BUY-OUT-BEV-POST").value <> 1 And Not preEdge) Then
            arrayEW = Split(straightEdgework, ",")
            For Each ew In arrayEW
                'EF - 01/06 - Added the following line of code to Explude the "EFPCN - Flat Polish CNC"
                If InStr(ew, "EFPCN")= 0 And InStr(ew, "ESEAM") = 0 Then
                    If ew <> "" Then
                        keyPairLinIN = Split(ew, "=")
                        linealIN += CSng(keyPairLinIN(1))
                    End If

                    If InStr(ew, "EFGPO") > 0 Then ' Furniture Grade Polish
                        linealINprePost += CSng(keyPairLinIN(1))
                    End If
                End If
            Next

            If Attributes.Exists("CP-EDGE-PREandPOST") And linealINprePost > 0 Then
                Attributes("CP-EDGE-PREandPOST").value = linealINprePost
            End If
        End If

        If sgpIL And Not (postEdge Or ((Attributes("ANNLAMI").value = 1 Or InStr(straightEdgework, "EFGPO") > 0) And Attributes("CP-BUY-OUT-BEV-POST").value <> 1 And Not preEdge)) Then
        	arrayEW = Split(straightEdgework, ",")
            For Each ew In arrayEW

            	                'EF - 01/06 - Added the following line of code to Explude the "EFPCN - Flat Polish CNC"
                If ew <> "" And InStr(ew, "EFGPO") > 0 And InStr(ew, "EFPCN")= 0 And InStr(ew, "ESEAM") = 0 Then
                	    keyPairLinIN = Split(ew, "=")
                        linealIN += CSng(keyPairLinIN(1))
                        linealINprePost += CSng(keyPairLinIN(1))

                End If
            Next

            If Attributes.Exists("CP-EDGE-PREandPOST") And linealINprePost > 0 Then
                Attributes("CP-EDGE-PREandPOST").value = linealINprePost
            End If
        End If


    End If

    If linealIN > 0 Then retval = linealIN

    'DO NOT MODIFY CODE BELOW THIS LINE
    AttributeValue = retval

End Function