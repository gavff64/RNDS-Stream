RUBYNDS := vendor/RubyNDS
RUBY ?= ruby
GAME := $(CURDIR)/dsi_stream_client.rb
NAME := RNDS-Stream
BUILD := $(CURDIR)/build
ASSET_BUILD := $(BUILD)/assets
ASSET_STAMP := $(BUILD)/.assets-built
VIDEO_ENCODER := $(abspath $(RUBYNDS)/build/r15v)

.DEFAULT_GOAL := all
.PHONY: all setup assets clean

all: assets
	$(MAKE) -C $(RUBYNDS) GAME=$(GAME) NAME=$(NAME) \
		ASSET_BUILD=$(ASSET_BUILD) ASSET_STAMP=$(ASSET_STAMP) NITROFS_FILES=
	cp $(RUBYNDS)/$(NAME).nds $(NAME).nds

setup:
	git submodule update --init
	cd $(RUBYNDS) && rake setup

assets:
	$(MAKE) -C $(RUBYNDS) build/r15v
	mkdir -p $(ASSET_BUILD)
	$(RUBY) $(RUBYNDS)/tools/assets.rb assets $(ASSET_BUILD) $(VIDEO_ENCODER)
	touch $(ASSET_STAMP)

clean:
	rm -rf $(BUILD)
	rm -f $(NAME).nds $(RUBYNDS)/$(NAME).nds

