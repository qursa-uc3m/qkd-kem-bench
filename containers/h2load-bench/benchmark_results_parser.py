import os
import re
import pandas as pd
import argparse

def parse_results(file_path, output_path):
    # Open the file and read all lines
    with open(file_path, 'r') as file:
        lines = file.readlines()
    os.makedirs(output_path, exist_ok=True)

    # Prepare dictionaries to store the parsed results
    summary_results = {}
    timing_results = {}

    for line in lines:
        # Check for summary line
        if "finished in" in line and "req/s," in line:
            parts = [part.strip() for part in line.split(",")]
            summary_results["Finished in (ms)"] = parts[0].split()[-1]
            summary_results["Req/s"] = parts[1].split()[0]
            summary_results["data/s"] = parts[2].split()[0]
        
        # Check for requests line
        elif "requests:" in line:
            # remove "requests:" from the line and strip
            line = line.replace("requests:", "").strip()
            parts = [part.strip() for part in line.split(",")]
            for part in parts:
                key, value = part.split()[1], part.split()[0]
                summary_results[f"requests_{key}"] = value

        # Check for traffic line
        elif "traffic:" in line and "total" in line and "headers" in line and "data" in line:
            # Extract and remove space savings data
            match = re.search(r'\(space savings (.*?)%\)', line)
            if match:
                space_savings = match.group(1)
                summary_results["traffic_space_savings (%)"] = space_savings
                line = line.replace(f"(space savings {space_savings}%)", "").strip()
            
            # remove "traffic:" from the line and strip
            line = line.replace("traffic:", "").strip()
            # remove substrings enclosed in parentheses
            line = re.sub(r'\([^)]*\)', '', line)
            parts = [part.strip() for part in line.split(",")]
            for part in parts:  # Exclude "traffic:" part
                key, value = part.split()[1], part.split()[0]
                summary_results[f"traffic_{key}"] = value

        # Check for specific timing lines
        line_identifiers = ["time for request:", "time for connect:", "time to 1st byte:", "req/s           :"]
        for identifier in line_identifiers:
            if identifier in line:
                timing_name = identifier.strip(': ')
                line_without_id = line.replace(identifier, '')
                line_parts = [part for part in line_without_id.split() if part]  # removing empty strings
                if len(line_parts) == 5:  # Check if we have all needed parts
                    timing_results[timing_name] = {
                        "Min": line_parts[0],
                        "Max": line_parts[1],
                        "Mean": line_parts[2],
                        "SD": line_parts[3],
                        "+/- SD (%)": line_parts[4]
                    }

    # Create pandas dataframes
    summary_df = pd.DataFrame([summary_results])
    timing_df = pd.DataFrame(timing_results).T
    timing_df.reset_index(inplace=True)
    
    # save dataframes to csv
    summary_df.to_csv(f'{output_path}/summary_df.csv', index=False)
    timing_df.to_csv(f'{output_path}/timing_df.csv', index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process a benchmark results file.')
    parser.add_argument('--file', '-f', type=str, required=True, help='The path to the input file')
    parser.add_argument('--output', '-o', type=str, required=False, help='The path to the output file')
    args = parser.parse_args()

    parse_results(args.file, args.output)