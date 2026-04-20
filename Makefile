PREFIX = /usr/local
install:
	cp fzmedia.sh ${PREFIX}/bin/fzmedia
uninstall:
	rm -f ${PREFIX}/bin/fzmedia
lint:
	shellcheck -s sh fzmedia.sh
