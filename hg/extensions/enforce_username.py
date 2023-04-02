"""enforce_username

Enforce that the username on commits matches the system username.
"""

from mercurial.i18n import _
from mercurial import (commands, extensions, error)
import inspect
import os
    
def extsetup(ui):
    def commitwrap(commit, ui, repo, *pats, **opts):
        if "IRON_FUNCTIONAL_TESTING" not in os.environ:
            os_login = str.encode(os.getlogin())
            if "HGUSER" in os.environ:
                if str.encode(os.getenv("HGUSER")) != os_login and not str.encode(os.getenv("HGUSER")).startswith(os_login + b'@'):
                    msg = _(
                        b"Commit user does not match OS username '%s'"
                    )
                    raise error.InputError(msg % os_login)
            elif 'user' in opts and opts['user'] is not None and opts['user'] != b'':
                if opts['user'] != os_login and not opts['user'].startswith(os_login + b'@'):
                    msg = _(
                        b"Commit user does not match OS username '%s'"
                    )
                    raise error.InputError(msg % os_login)            
            else:
                opts['user'] = os_login
        return commit(ui, repo, *pats, **opts)
    extensions.wrapcommand(commands.table, b'commit', commitwrap)
