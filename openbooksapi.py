import csv
import requests
import re

def get_isbn_from_title_author(title, author):
    """Retrieves an ISBN using the Open Library Search API."""
    query = f"title:{title} AND author:{author}"
    url = f"https://openlibrary.org/search.json?q={query}"
    try:
        response = requests.get(url)
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
        data = response.json()

        if data.get("docs"):
            doc = data["docs"][0]
            isbn = doc.get("isbn")
            if isbn:
                # Prioritize ISBN13
                isbn13s = [i for i in isbn if re.match(r"^978", i)]
                if isbn13s:
                    return isbn13s[0]
                return isbn[0] # Return the first ISBN if no ISBN13 found
        return None # Return None if no ISBN found
    except requests.exceptions.RequestException as e:
        print(f"Error querying Open Library API: {e}")
        return None
    except IndexError:
        print(f"No results found for {title} by {author}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return None


def add_isbn_to_csv(input_filename, output_filename):
    """Adds an ISBN column to a CSV file using Open Library API."""
    try:
        with open(input_filename, 'r', newline='', encoding='utf-8') as infile, \
                open(output_filename, 'w', newline='', encoding='utf-8') as outfile:

            reader = csv.reader(infile)
            writer = csv.writer(outfile)

            header = next(reader)
            header.insert(0, "ISBN")
            writer.writerow(header)

            for row in reader:
                title = row[0]
                author = row[1]
                isbn = get_isbn_from_title_author(title, author)
                row.insert(0, isbn if isbn else "ISBN Not Found")  # Insert ISBN or message
                writer.writerow(row)
                print(isbn)

        print(f"ISBNs added to {output_filename}")

    except FileNotFoundError:
        print(f"Error: Input file '{input_filename}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")


# Example usage (same as before):
input_file = "books.csv"
output_file = "books_with_isbn.csv"


add_isbn_to_csv(input_file, output_file)
