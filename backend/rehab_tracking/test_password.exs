password = "TestPassword123"
hash = "$2b$12$K.0OJ5JQHZL4C0brZFuCaOV3IRqbDRWg1McROtyM5H.Ul9s3t.6ym"

result = Bcrypt.verify_pass(password, hash)
IO.puts("Password verification result: #{result}")

# Also test creating a new hash
new_hash = Bcrypt.hash_pwd_salt(password)
IO.puts("New hash: #{new_hash}")
IO.puts("New hash verification: #{Bcrypt.verify_pass(password, new_hash)}")