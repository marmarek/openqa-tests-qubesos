# The Qubes OS Project, https://www.qubes-os.org/
#
# Copyright (C) 2020 Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use base "installedtest";
use strict;
use testapi;
use networking;
use utils qw(us_colemak colemak_us);

sub run {
    my ($self) = @_;

    select_console('x11');
    x11_start_program('xterm');
    send_key('alt-f10');
    curl_via_netvm;

    if (check_var('MODIFY_REPO_CONF', '1')) {
        # just any modification, to trigger .rpmnew file
        assert_script_run("echo | sudo tee -a /etc/yum.repos.d/qubes-dom0.repo");
    }

    script_run("pkill xscreensaver");

    #assert_script_run("sudo qubes-dom0-update --enablerepo=qubes-dom0-current-testing -y qubes-dist-upgrade");
    #assert_script_run("curl https://raw.githubusercontent.com/marmarek/qubes-dist-upgrade/r4.0-fixes20210115/qubes-dist-upgrade.sh > migration.sh");
    assert_script_run("curl https://raw.githubusercontent.com/fepitre/qubes-dist-upgrade/update-templates/qubes-dist-upgrade.sh > migration.sh");
    assert_script_run("curl https://raw.githubusercontent.com/fepitre/qubes-dist-upgrade/update-templates/qubes-hooks.py > qubes-hooks.py");
    assert_script_run("curl https://raw.githubusercontent.com/fepitre/qubes-dist-upgrade/update-templates/scripts/upgrade-template-standalone.sh > upgrade-template-standalone.sh");
    assert_script_run("chmod +x migration.sh");
    assert_script_run("chmod +x upgrade-template-standalone.sh");
    assert_script_run("sudo cp migration.sh /usr/sbin/qubes-dist-upgrade");
    assert_script_run("sudo mkdir -p /usr/sbin/scripts/");
    assert_script_run("sudo cp upgrade-template-standalone.sh /usr/sbin/scripts/");
    assert_script_run("sudo cp qubes-hooks.py /usr/sbin/qubes-hooks.py");


    assert_script_run("script -a -e -c 'sudo qubes-dist-upgrade --all --assumeyes' release-upgrade.log", timeout => 10800);
    sleep(1);
    send_key('ctrl-c');

    # reset keyboard layout (but still test if after reboot)
    if (check_var('KEYBOARD_LAYOUT', 'us-colemak')) {
        x11_start_program(us_colemak('setxkbmap us'), valid => 0);
    } elsif (get_var('LOCALE')) {
        x11_start_program('setxkbmap us', valid => 0);
    }
    sleep(1);
    send_key('ctrl-c');

    # install qubesteststub module for updated python version
    assert_script_run("sudo sh -c 'cd /root/extra-files; python3 ./setup.py install'");

    set_var('VERSION', '4.1');
    if (check_var('UEFI_DIRECT', '1')) {
        set_var('UEFI_DIRECT', '');
    }
    set_var('KEEP_SCREENLOCKER', '1');

    script_run("sudo reboot", timeout => 0);
    assert_screen ["bootloader", "luks-prompt", "login-prompt-user-selected"], 300;
    $self->handle_system_startup;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { fatal => 1, milestone => 1 };
}


sub post_fail_hook {
    my $self = shift;

    script_run "cat /home/user/release-upgrade.log";
    $self->SUPER::post_fail_hook();
    upload_logs('/home/user/release-upgrade.log', failok => 1);
};

1;

# vim: set sw=4 et:
