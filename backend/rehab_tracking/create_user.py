import bcrypt

password = "TestPassword123!"
salt = bcrypt.gensalt()
hash = bcrypt.hashpw(password.encode('utf-8'), salt)
print(hash.decode('utf-8'))
