import csv
import requests
import json
import concurrent.futures
import time

def get_isbn_from_google_books(title, author):
    """Retrieves an ISBN using the Google Books API."""
    query = f"intitle:{title}+inauthor:{author}"
    url = f"https://www.googleapis.com/books/v1/volumes?q={query}"

    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()

        if data.get("totalItems", 0) > 0:
            volume_info = data["items"][0].get("volumeInfo", {})
            industry_identifiers = volume_info.get("industryIdentifiers", [])

            isbn13 = next((id["identifier"] for id in industry_identifiers if id["type"] == "ISBN_13"), None)
            isbn10 = next((id["identifier"] for id in industry_identifiers if id["type"] == "ISBN_10"), None)

            if isbn13:
                print(f"Found ISBN: {isbn13} for '{title}' by {author}")
                return isbn13
            elif isbn10:
                print(f"Found ISBN (ISBN10): {isbn10} for '{title}' by {author}")
                return isbn10
            else:
                print(f"No ISBN found in Google Books data for '{title}' by {author}")
                return None
        else:
            print(f"No results found in Google Books for '{title}' by {author}")
            return None

    except requests.exceptions.RequestException as e:
        print(f"Error querying Google Books API for '{title}' by {author}: {e}")
        return None
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON response from Google Books API for '{title}' by {author}: {e}, Response Text: {response.text}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred for '{title}' by {author}: {e}")
        return None


def process_row(row):
    """Processes a single row to get and add the ISBN."""
    title = row[0]
    author = row[1]
    isbn = get_isbn_from_google_books(title, author)
    row.insert(0, isbn if isbn else "ISBN Not Found")
    return row

def add_isbn_to_csv(input_filename, output_filename, max_workers=10):
    """Adds ISBNs to a CSV using multithreading."""
    start_time = time.time()
    try:
        with open(input_filename, 'r', newline='', encoding='utf-8') as infile, \
                open(output_filename, 'w', newline='', encoding='utf-8') as outfile:

            reader = csv.reader(infile)
            writer = csv.writer(outfile)

            header = next(reader)
            header.insert(0, "ISBN")
            writer.writerow(header)

            with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                futures = [executor.submit(process_row, row) for row in reader]
                for future in concurrent.futures.as_completed(futures):
                    try:
                        updated_row = future.result()
                        writer.writerow(updated_row)
                    except Exception as e:
                        print(f"Error processing a row: {e}")
                        continue

        end_time = time.time()
        print(f"ISBNs added to {output_filename} in {end_time - start_time:.2f} seconds")

    except FileNotFoundError:
        print(f"Error: Input file '{input_filename}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

# ... (Example usage and file creation remain the same)
# Example usage (same as before):
input_file = "books.csv"
output_file = "books_with_isbn_google.csv"

add_isbn_to_csv(input_file, output_file)
