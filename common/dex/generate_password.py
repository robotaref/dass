import json
from os.path import join
import pathlib

from passlib.hash import bcrypt
import getpass
import yaml

if __name__ == '__main__':
    base_path = pathlib.Path(__file__).parent.resolve()
    print(base_path)
    config_path = join(base_path, "base/config-map.yaml")
    with open(config_path, 'r') as file:
        config = yaml.load(file, Loader=yaml.SafeLoader)
        user_config = (config['data']['config.yaml']['staticPasswords'][0])
        print("Please provide the user")
        new_config = {'userID': user_config['userID'], 'username': input("Username:\t\n"), 'email': input("Email:\t\n")}

        password = getpass.getpass()

        hashed_password = bcrypt.using(rounds=12, ident="2y").hash(password)
        new_config['hash'] = hashed_password
        config['data']['config.yaml']['staticPasswords'][0] = new_config
    with open(config_path, 'w') as file:
        documents = yaml.dump(config, file)
