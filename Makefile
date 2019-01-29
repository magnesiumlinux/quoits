
prefix=/usr

ifndef DESTDIR
    DESTDIR = ''
endif

tools="keyctrl mounty netutil nextuser optmount pod quoits.sh svtool tz usertool wifi"

all:
	echo "Nothing to do!"

install:
	install -d ${DESTDIR}${prefix}/sbin
	for t in ${tools}; do install -m 0755 $$t ${DESTDIR}${prefix}/sbin; done

	install -d ${DESTDIR}${prefix}/etc/runit
	cp -a runit/* ${DESTDIR}${prefix}/etc/runit

	mkdir -p ${DESTDIR}${prefix}/share
	cp quoits.intro ${DESTDIR}${prefix}/share/quoits.intro


