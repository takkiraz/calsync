BIN = calsync
AGENT = personal.calsync
PLIST = $(HOME)/Library/LaunchAgents/$(AGENT).plist

.PHONY: list dry-run sync deploy undeploy

$(BIN): calsync.swift Info.plist
	swiftc -O calsync.swift -o $(BIN) -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist

list dry-run sync: $(BIN)
	./$(BIN) $@

deploy: $(BIN)
	sed -e "s|__BIN__|$(CURDIR)/$(BIN)|" -e "s|__HOME__|$(HOME)|" $(AGENT).plist > $(PLIST)
	-launchctl bootout gui/$$(id -u)/$(AGENT) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(PLIST)

undeploy:
	launchctl bootout gui/$$(id -u)/$(AGENT)
