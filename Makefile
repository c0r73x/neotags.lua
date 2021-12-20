#
# Makefile
# c0r73x, 2021-12-20 16:40
#

.PHONY: moon
all: moon

moon:
	@mkdir -p ./lua &> /dev/null
	@moonc -t /tmp ./moon/
	@cp -r /tmp/moon/* ./lua
	@rm -rf /tmp/moon

# vim:ft=make
