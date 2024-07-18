PREFIX = /usr/local
install:
	cp fzmedia.sh ${DESTDIR}${PREFIX}/bin/fzmedia
uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/fzmedia\
