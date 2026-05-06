""" Edit Value

This is a simple YAML value editor.  It will handle nested values, but only if those values already exist in the file being edited.

Ex) Given the following YAML file (/path/to/file.yaml):

imageTags:
  image1: tag1
  image2: tag2

To set 'image2' to 'tag3', 

python3 ./scripts/edit-value --value imageTags.image2=tag3 /path/to/file.yaml

"""
import yaml
import argparse

parser = argparse.ArgumentParser(description='Edit Values file.')
parser.add_argument('file', help='The yaml file to be edited')
parser.add_argument('--value', action='append', help='values to be set')

args = parser.parse_args()

print(f"{args.value}")

with open(args.file) as f:
     values_doc = yaml.safe_load(f)

for x in args.value:
     equalIndex = x.index("=")
     value = str(x[equalIndex+1:])
     key= str(x[:equalIndex])
     print(f"Key = {key}, value = {value}")

     key_split = key.split(".")
     keyLength = len(key_split)
     if (keyLength == 1):
          values_doc[key_split[0]] = value
     elif (keyLength == 2):
          values_doc[key_split[0]][key_split[1]] = value
     elif (keyLength == 3):
          values_doc[key_split[0]][key_split[1]][key_split[2]] = value
     elif (keyLength == 4):
          values_doc[key_split[0]][key_split[1]][key_split[2]][key_split[3]] = value


with open(args.file, "w") as f:
    yaml.dump(values_doc, f, default_flow_style=False)