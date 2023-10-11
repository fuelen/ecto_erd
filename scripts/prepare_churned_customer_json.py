import json
import os

# initialize an empty dictionary
erd_dict = {}

# add an element to the dictionary
erd_dict['tables'] = []

# create a function that will iterate over erd_dict['tables'] and find the current_table_name and return the index
def find_table_index(current_table_name):
    for index, table in enumerate(erd_dict['tables']):
        if table['table_name'] == current_table_name:
            return index

# Populate all tables and primary keys

# initialize a new table
new_table = True
current_table_name = ""
table_index = -9999

with open('/tmp/ecto_erd.qdbd', 'r') as f:
    # read file line by line
    for line in f:
        if new_table == True:
            # add a new table to the dictionary
            current_table_name = line.strip()
            table_index = find_table_index(current_table_name)
            if table_index == None:
                erd_dict['tables'].append({'table_name': line.strip(), 'referenced_by': []})
                table_index = find_table_index(current_table_name)
            new_table = False

        if line.strip() == '---':
            continue

        # if the line is empty, then we are at the end of the table
        if line.strip() == '':
            new_table = True
            current_table_name = ""
            table_index = -9999
            continue

        # find substring PK in the line
        if 'PK' in line:
            split_line = line.split()
            # get first element of the split_line
            primary_key = split_line[0].strip()

            # add an element to the dictionary, with key as primary_key and value as the primary_key, where the table_name is equal to current_table_name

            erd_dict['tables'][table_index]['primary_key'] = primary_key


        # find substring FK in the line
        if ' FK >- ' in line:
            split_line = line.split(' FK >- ')
            # get first element of the split_line
            first = split_line[0].strip()
            last = split_line[1].strip()

            first_split = first.split()
            foreign_key = first_split[0].strip()

            last_split = last.split('.')
            foreign_table = last_split[0].strip()

            # add an element to the dictionary, with key as foreign_key and value as the foreign_key, where the table_name is equal to current_table_name
            primary_key_table_index = find_table_index(foreign_table)
            if primary_key_table_index == None:
                erd_dict['tables'].append({'table_name': foreign_table, 'referenced_by': []})
                primary_key_table_index = find_table_index(foreign_table)

            if not (current_table_name == 'favorite_video_styles' and foreign_table == 'users'):
                erd_dict['tables'][primary_key_table_index]['referenced_by'].append({'table_name': current_table_name, 'foreign_key': foreign_key})

# Dump the dictionary to a json file
with open('/tmp/ecto_erd.json', 'w') as f:
    f.write(json.dumps(erd_dict, indent=4))

# Find environment to prepare for S3 Upload
if "GITHUB_REF" in os.environ:
    GITHUB_REF = os.environ["GITHUB_REF"]
else:
    GITHUB_REF = ""

if GITHUB_REF == None or GITHUB_REF.strip() == "":
    BUCKET = "fw-temp-gdpr-deleted-data-loop-staging"
    ENVIRONMENT = "local"
else:
    GITHUB_BRANCH_NAME = GITHUB_REF.split('/')[-1]

    # if GITHUB_BRANCH_NAME contains substring prod
    if GITHUB_BRANCH_NAME.find("master") != -1:
        BUCKET = "fw-temp-gdpr-deleted-data-loop-prod"
        ENVIRONMENT = "prod"
    else:
        BUCKET = "fw-temp-gdpr-deleted-data-loop-staging"
        if GITHUB_BRANCH_NAME.find("staging") != -1:
            ENVIRONMENT = "staging"
        elif GITHUB_BRANCH_NAME.find("dev") != -1:
            ENVIRONMENT = "dev"
        elif GITHUB_BRANCH_NAME.find("sandbox") != -1:
            ENVIRONMENT = "sandbox"
        else:
            ENVIRONMENT = "unknown"

# Upload json file to S3
# Deliberately not using boto3 to avoid dependency
os.system("aws s3 cp /tmp/ecto_erd.json s3://" + BUCKET + "/" + ENVIRONMENT +  "/ecto_erd.json")
