FROM pierres/archlinux
RUN pacman -Syu --noconfirm --needed base-devel devtools kcov bash-bats
RUN pacman-key --init
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
RUN useradd -N -g users -G wheel -m tester
RUN install -d -m 1777 /build
USER tester
RUN echo -e "\
%echo Generating signing key...\n\
Key-Type: RSA\n\
Key-Length: 1024\n\
Key-Usage: sign\n\
Name-Real: Bob Tester\n\
Name-Email: tester@localhost\n\
Expire-Date: 0\n\
%no-protection\n\
%commit\n\
%echo Done\n"\
| gpg --quiet --batch --no-tty --no-permission-warning --gen-key
RUN gpg --export | sudo pacman-key -a -
RUN sudo pacman-key --lsign-key tester@localhost
ENV BUILDDIR=/build
ENV PACKAGER="Bob Tester <tester@localhost>"
