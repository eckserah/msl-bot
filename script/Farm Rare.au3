;function: farmRare
;-Automatically farms rares in story mode
;pre:
;   -config must be set for script
;   -required config keys: map, capture, guardian-dungeon
;author: GkevinOD
Func farmRare()
	;beginning script
	setLog("*Report any issues/bugs in GitHub", 2)
	setLog("*Loading config for Farm Rare.", 2)

	;getting configs
	Dim $intStartTime = TimerInit()
	Dim $intTimeElapse = 0;

	Dim $intCheckStartTime; check if stuck
	Dim $intCheckTime; check if stuck

	Dim $map = "map-" & StringReplace(IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "map", "phantom forest"), " ", "-")
	Dim $guardian = IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "guardian-dungeon", "0")
	Dim $difficulty = IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "difficulty", "normal")
	Dim $captures[0] ;
	Dim $sellGems = StringSplit(IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "sell-gems-grade", "one star,two star, three star"), ",", 2)

	Dim $intGem = Int(IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "max-spend-gem", 0))
	Dim $intGemUsed = 0

	Dim $rawCapture = StringSplit(IniRead(@ScriptDir & "/" & $botConfig, "Farm Rare", "capture", "legendary,super rare,rare,exotic"), ",", 2)
	For $capture In $rawCapture
		Local $grade = StringReplace($capture, " ", "-")
		If FileExists(@ScriptDir & "/core/images/catch/catch-" & $grade & ".bmp") Then
			_ArrayAdd($captures, "catch-" & $grade)
		EndIf
	Next

	setLog("~~~Starting 'Farm Rare' script~~~", 2)

	;setting up data capture
	Local $dataRuns = 0
	Local $dataGuardians = 0
	Local $dataEncounter = 0
	Local $dataStrCaught = ""
	Local $counterWordWrap = 0
	Local $getHourly = False

	While True
		While True
			$intTimeElapse = Int(TimerDiff($intStartTime) / 1000)

			GUICtrlSetData($listScript, "")
			GUICtrlSetData($listScript, "Runs: " & $dataRuns & " (Guardian: " & $dataGuardians & ")|Rares: " & $dataEncounter & "|Caught: " & StringMid($dataStrCaught, 2) & "|Gems Used: " & ($intGemUsed & "/" & $intGem) & "|Time Elapse: " & StringFormat("%.2f", $intTimeElapse / 60) & " Min.")

			If StringSplit(_NowTime(4), ":", 2)[1] = "00" Then $getHourly = True

			If _Sleep(100) Then ExitLoop (2) ;to stop farming
			Switch getLocation()
				Case "map", "map-stage", "astroleague", "village", "manage", "monsters", "quests", "map-battle", "clan", "esc", "inbox"
					If setLog("Going into battle...", 1) Then ExitLoop (2)
					If navigate("map") = 1 Then
						If enterStage($map, $difficulty, False, True) = 0 Then
							If setLog("Error: Could not enter map stage.", 1) Then ExitLoop (2)
						Else
							$dataRuns += 1
							$intCheckStartTime = TimerInit()
							If setLog("Waiting for astromon.", 1) Then ExitLoop (2)
						EndIf
					EndIf
				Case "battle-end-exp", "battle-sell"
					clickPointUntil($game_coorTap, "battle-end")
				Case "pause"
					clickPoint($battle_coorContinue)
				Case "unknown"
					clickPoint($game_coorTap)

					Local $closePoint = findImageFiles("misc-close", 30)
					If isArray($closePoint) Then
						clickPoint($closePoint) ;to close any windows open
					EndIf
				Case "battle-end"
					$intCheckStartTime = 0

					If checkPixel($battle_pixelQuest) = True Then
						If setLogReplace("Collecting quests...", 1) Then ExitLoop (2)
						If navigate("village", "quests") = 1 Then
							For $questTab In $village_coorArrayQuestsTab ;quest tabs
								clickPoint(StringSplit($questTab, ",", 2))
								While IsArray(findImageWait("misc-quests-get-reward", 3, 100)) = True
									If _Sleep(10) Then ExitLoop (5)
									clickImage("misc-quests-get-reward", 100)
								WEnd
							Next
						EndIf
						If setLogReplace("Collecting quests... Done!", 1) Then ExitLoop (2)
					EndIf

					If $getHourly = True Then
						If getHourly() = 1 Then
							$getHourly = False
						EndIf
					EndIf

					If getLocation() = "battle-end" Then
						If Not Mod($dataRuns, 20) = 0 Then
							clickImageUntil("battle-quick-restart", "unknown")
							$dataRuns += 1
							$intCheckStartTime = TimerInit()
						Else
							If $guardian = 1 Then
								ExitLoop
							EndIf

							If getLocation() = "battle-end" Then
								clickImageUntil("battle-quick-restart", "unknown")
								$dataRuns += 1
								$intCheckStartTime = TimerInit()
							EndIf
						EndIf
					EndIf
				Case "refill"
					If $intGemUsed + 30 <= $intGem Then
						clickPointUntil($game_coorRefill, "refill-confirm")
						clickPointUntil($game_coorRefillConfirm, "refill")

						If checkLocations("buy-gem") Then
							setLog("Out of gems!", 1)
							ExitLoop (2)
						EndIf

						ControlSend($hWindow, "", "", "{ESC}")

						setLog("Refill gems: " & $intGemUsed + 30 & "/" & $intGem)
						$intGemUsed += 30

						navigate("map") ;sometimes it gets stuck and adds 20 runs
						$dataRuns -= 1
					Else
						setLog("Gem used exceed max gems!")
						ExitLoop (2)
					EndIf
					clickPointUntil($map_coorBattle, "battle")
				Case "battle"
					Local $intCheckTime = Int(TimerDiff($intCheckStartTime) / 1000)
					If Not($intCheckStartTime = 0) And ($intCheckTime > 180) Then
						If setLog("Battle has not finished in 3 minutes! Attacking..", 1) Then ExitLoop (2)
						clickPoint($battle_coorAuto)
						$intCheckStartTime = TimerInit() ;reset timer
					EndIf

					If IsArray(findImagesFiles($imagesRareAstromon, 100)) Then
						If checkPixel($battle_pixelUnavailable) = False Then ;if there is more astrochips
							$dataEncounter += 1
							If setLog("An astromon has been found!", 1) Then ExitLoop (2)

							If navigate("battle", "catch-mode") = 1 Then
								Local $tempStr = catch($captures, True, False, False, True)
								If $tempStr = -2 Then ;double check
									If setLog("Did not recognize astromon, trying again..", 1) Then ExitLoop (2)

									navigate("battle", "catch-mode")
									$tempStr = catch($captures, True, True, False, True)
								EndIf
								If $tempStr = "-2" Then $tempStr = ""

								If Not $tempStr = "" Then
									$counterWordWrap += 1
									$dataStrCaught &= ", " & $tempStr

									If Mod($counterWordWrap, 11) = 0 Then $dataStrCaught &= "|.........."
								EndIf
								If setLog("Finish catching... Attacking", 1) Then ExitLoop (2)
								clickPoint($battle_coorAuto)
							EndIf
						Else ;if no more astrochips
							If setLog("No astrochips left... Attacking", 1) Then ExitLoop (2)
							clickPoint($battle_coorAuto)
						EndIf
						$intCheckStartTime = TimerInit()
					EndIf
				Case "map-gem-full", "battle-gem-full"
					If setLogReplace("Gem is full, going to sell gems...", 1) Then ExitLoop (2)
					If navigate("village", "manage") = 1 Then
						sellGems($sellGems)
						If setLogReplace("Gem is full, going to sell gems... Done!", 1) Then ExitLoop (2)
					EndIf
				Case "lost-connection"
					clickPoint($game_coorConnectionRetry)
			EndSwitch
		WEnd

		Dim $foundDungeon = 0
		If $guardian = 1 And navigate("map", "guardian-dungeons") = 1 Then
			If setLog("Checking for guardian dungeons...", 1) Then ExitLoop (2)
			Local $currLocation = getLocation()

			While $currLocation = "guardian-dungeons"
				Local $energyPoint = findImageFiles("misc-dungeon-energy", 50)
				If isArray($energyPoint) And (clickPointUntil($energyPoint, "map-battle", 50) = 1) Then
					clickPointWait($map_coorBattle, "map-battle", 5)

					If _Sleep(500) Then ExitLoop (2)

					If checkLocations("map-gem-full", "battle-gem-full") = 1 Then
						If setLog("Gem is full, going to sell gems...", 1) Then ExitLoop (2)
						If navigate("village", "manage") = 1 Then
							ControlSend($hWindow, "", "", "{ESC}")
							clickPointWait($village_coorManage, "monsters")

							navigate("village", "manage")
							sellGems($sellGems)
						EndIf

						clickImageUntil("misc-dungeon-energy", "map-battle", 50)
						clickPointWait($map_coorBattle, "map-battle", 5)
					EndIf

					If checkLocations("refill") = 1 Then
						If $intGemUsed + 30 <= $intGem Then
							clickPointUntil($game_coorRefill, "refill-confirm")
							clickPointUntil($game_coorRefillConfirm, "refill")

							If checkLocations("buy-gem") Then
								setLog("Out of gems!", 1)
								ExitLoop
							EndIf

							ControlSend($hWindow, "", "", "{ESC}")

							setLog("Refill gems: " & $intGemUsed + 30 & "/" & $intGem)
							$intGemUsed += 30
						Else
							setLog("Gem used exceed max gems!")
							ExitLoop
						EndIf
						clickPointWait($map_coorBattle, "map-battle", 5)
					EndIf

					$foundDungeon += 1
					If setLogReplace("Found dungeon, attacking x" & $foundDungeon & ".", 1) Then ExitLoop (2)

					Local $initTime = TimerInit()
					While True
						_Sleep(1000)
						If getLocation() = "battle-end-exp" Then ExitLoop

						If Int(TimerDiff($initTime)/1000) > 240 Then
							If setLog("Error: Could not finish Guardian dungeon within 5 minutes, exiting.") Then ExitLoop(2)
							navigate("map")

							ExitLoop
						EndIf
					WEnd

					clickPointUntil($game_coorTap, "battle-end", 20, 1000)
					clickImageUntil("battle-exit", "guardian-dungeons", 20)

					waitLocation("guardian-dungeons", 10000)
					$currLocation = getLocation()
				Else
					If setLog("Guardian dungeon not found, going back to map.", 1) Then ExitLoop (2)
					navigate("map")
					ExitLoop
				EndIf
			WEnd
		EndIf
		$dataGuardians += $foundDungeon
	WEnd

	setLog("~~~Finished 'Farm Rare' script~~~", 2)
EndFunc   ;==>farmRare
