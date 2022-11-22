#
# Makefile
# c0r73x, 2021-12-20 16:40
#

.PHONY: yue
all: yue

yue:
	@mkdir -p ./lua &> /dev/null
	@yue -s -m -t /tmp/yue ./yue
	@cp -r /tmp/yue/* ./lua
	@rm -rf /tmp/yue

# vim:ft=make
