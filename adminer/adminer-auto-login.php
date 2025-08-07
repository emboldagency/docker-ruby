<?php

class AdminerAutoLogin
{
    public function credentials()
    {
        // Return array: [server, username, password]
        return [
            getenv('ADMINER_DEFAULT_SERVER') ?: 'postgres',
            getenv('ADMINER_DEFAULT_USERNAME') ?: 'embold',
            getenv('ADMINER_DEFAULT_PASSWORD') ?: 'embold'
        ];
    }

    public function loginFormField($name, $heading, $value)
    {
        // Preselect driver/system
        if ($name == 'driver') {
            $driver = getenv('ADMINER_DEFAULT_DRIVER') ?: 'pgsql';
            return $heading . '<select name="auth[driver]">'
                . '<option value="server"' . ($driver == 'server' ? ' selected' : '') . '>MySQL</option>'
                . '<option value="pgsql"' . ($driver == 'pgsql' ? ' selected' : '') . '>PostgreSQL</option>'
                . '<option value="sqlite"' . ($driver == 'sqlite' ? ' selected' : '') . '>SQLite</option>'
                . '<option value="oracle"' . ($driver == 'oracle' ? ' selected' : '') . '>Oracle</option>'
                . '<option value="mssql"' . ($driver == 'mssql' ? ' selected' : '') . '>MS SQL</option>'
                . '</select>';
        }
        // Prefill username
        if ($name == 'username') {
            $username = getenv('ADMINER_DEFAULT_USERNAME') ?: 'embold';
            return $heading . '<input name="auth[username]" value="' . htmlspecialchars($username) . '">';
        }
        // Prefill password
        if ($name == 'password') {
            $password = getenv('ADMINER_DEFAULT_PASSWORD') ?: 'embold';
            return $heading . '<input type="password" name="auth[password]" value="' . htmlspecialchars($password) . '">';
        }
        // Prefill database
        if ($name == 'db') {
            $db = getenv('ADMINER_DEFAULT_DB') ?: 'postgres';
            return $heading . '<input name="auth[db]" value="' . htmlspecialchars($db) . '">';
        }
        // Default rendering for other fields
        return null;
    }
}
return new AdminerAutoLogin();