import argparse
import json
import requests
import os

"""
Gets the most starred github repositories for language Y.
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    # add in the arguments for language and number of repositories you want.
    parser.add_argument("lang", help="language that you want to get repositories for")

    # add in arguments for github username and api key.
    parser.add_argument("github_username", help="your github username")
    parser.add_argument("api_key", help="you github personal token.")

    args = parser.parse_args()

    s = requests.Session()
    s.auth = (args.github_username, args.api_key)
    s.headers.update({'Accept': 'application/vnd.github.cloak-preview+json'})

    url = 'https://api.github.com/search/repositories?q='+ args.lang + '&s=stars&type=Repositories'
    r = s.get(url)
    pretty_json = json.loads(r.text)

    with open('projects.txt', 'w') as f:
        for repo in pretty_json["items"]:
            f.write(repo["html_url"]+"\n")
