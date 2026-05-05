PREFIX = /usr/local
install:
	cp fzmedia.sh ${PREFIX}/bin/fzmedia
uninstall:
	rm -f ${PREFIX}/bin/fzmedia
lint:
	shellcheck -s sh fzmedia.sh
fmt-diff:
	shfmt -s -d -sr -ci -i 2 -p fzmedia.sh
fmt:
	shfmt -s -w -sr -ci -i 2 -p fzmedia.sh
