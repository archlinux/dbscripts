FROM archlinux/base
RUN pacman -Syu --noconfirm --needed sudo fakeroot awk subversion make kcov bash-bats gettext grep
RUN pacman-key --init
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
RUN useradd -N -g users -G wheel -d /build -m tester
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
ENV BUILDDIR=/build
ENV PACKAGER="Bob Tester <tester@localhost>"
