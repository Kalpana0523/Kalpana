def get_value(obj, key):
   keys = key.split('/')    #split the key by '/'
   value = obj

   for k in keys:
       if isinstance(value, dict) or  k in value:
          value = value[k]
       else: 
          return None
   return value

my_object = {"a": {"b": {"c": "d"}}}
my_key = "a/b/c"
result = get_value(my_object, my_key)
print(result)     #output: d

my_object = {"x": {"y": {"z": "a"}}}
my_key = "x/y/z"
result = get_value(my_object, my_key)
print(result)     #output: a

