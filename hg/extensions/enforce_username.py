"""enforce_username

Enforce that the username on commits matches the system username.
"""

from mercurial.i18n import _
from mercurial import (commands, extensions, error)
import inspect
import os
import re

def extsetup(ui):
    def commitwrap(commit, ui, repo, *pats, **opts):
        if "IRON_FUNCTIONAL_TESTING" not in os.environ:
            os_login = str.encode(os.getlogin())
            pat = re.compile(b'^(%s|%s@\S+|(\S+ )+<%s@\S+>)$' % (os_login, os_login, os_login))
            if "HGUSER" in os.environ:
                hguser = str.encode(os.getenv("HGUSER"))
                if pat.match(hguser) is None:
                    msg = _(
                        b"Commit user '%s' does not match OS username '%s'"
                    )
                    raise error.InputError(msg % (hguser, os_login))
            elif 'user' in opts and opts['user'] is not None and opts['user'] != b'':                
                if pat.match(opts['user']) is None:
                    msg = _(
                        b"Commit user '%s' does not match OS username '%s'"
                    )
                    raise error.InputError(msg % (opts['user'], os_login))
            else:
                opts['user'] = os_login
        return commit(ui, repo, *pats, **opts)
    extensions.wrapcommand(commands.table, b'commit', commitwrap)
