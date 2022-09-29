FROM docker.io/archlinux/archlinux
RUN pacman -Syu --noconfirm --needed sudo fakeroot awk subversion make kcov bash-bats gettext grep tree binutils git
RUN pacman-key --init
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
RUN useradd -N -g users -G wheel -d /build -m tester
RUN	ln -sf /dbscripts/db-archive /usr/local/bin/ && \
	ln -sf /dbscripts/db-move /usr/local/bin/ && \
	ln -sf /dbscripts/db-remove /usr/local/bin/ && \
	ln -sf /dbscripts/db-repo-add /usr/local/bin/ && \
	ln -sf /dbscripts/db-repo-remove /usr/local/bin/ && \
	ln -sf /dbscripts/db-update /usr/local/bin/ && \
	ln -sf /dbscripts/testing2x /usr/local/bin/ && \
	ln -sf /dbscripts/cron-jobs/devlist-mailer /usr/local/bin/ && \
	ln -sf /dbscripts/cron-jobs/ftpdir-cleanup /usr/local/bin/ && \
	ln -sf /dbscripts/cron-jobs/integrity-check /usr/local/bin/ && \
	ln -sf /dbscripts/cron-jobs/sourceballs /usr/local/bin/

USER tester
RUN echo -e "\
Key-Type: RSA\n\
Key-Length: 1024\n\
Key-Usage: sign\n\
Name-Real: Bob Tester\n\
Name-Email: tester@localhost\n\
Expire-Date: 0\n\
%no-protection\n\
%commit\n"\
| gpg --quiet --batch --no-tty --no-permission-warning --gen-key
RUN gpg --export | sudo pacman-key -a -
RUN sudo pacman-key --lsign-key tester@localhost
ENV PACKAGER="Bob Tester <tester@localhost>"
