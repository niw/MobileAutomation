.DEFAULT_GOAL := format

.PHONY: xcodegen
xcodegen:
	cd Applications/MobileAutomationAgent && xcodegen 
	cd Applications/MobileAutomationClient && xcodegen 

.PHONY: format
format:
	swiftformat Applications Packages
