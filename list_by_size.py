#!/usr/bin/env python3
import os
import sys
import argparse
import time
from pathlib import Path
from collections import defaultdict, Counter
import math


def format_size(size_bytes):
    """Convert byte size to human-readable format."""
    if size_bytes == 0:
        return "0B"
    size_names = ("B", "KB", "MB", "GB", "TB", "PB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    # If the size is in GB, display as MB instead
    if i == 3:
        i = 2
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    
    # Format with commas for MB values >= 1,000
    if i == 2 and s >= 1000:
        return f"{s:,.2f} {size_names[i]}"
    
    return f"{s} {size_names[i]}"


def get_file_size(path):
    """Get file size safely, handling potential errors."""
    try:
        return os.path.getsize(path)
    except (OSError, PermissionError):
        return 0


def get_dir_size(path, visited=None, max_depth=2, current_depth=0, show_progress=True, 
                show_warnings=False, include_hidden=True, error_count=None):
    """Calculate total size of a directory recursively.
    
    Args:
        path: Path to the directory
        visited: Set of visited inodes to avoid symlink loops
        max_depth: Maximum recursion depth
        current_depth: Current recursion depth
        show_progress: Whether to show progress indicator
        show_warnings: Whether to show permission warnings
        include_hidden: Whether to include hidden files/directories
        error_count: Counter for tracking error types
    
    Returns:
        Total size in bytes
    """
    if visited is None:
        visited = set()
    if error_count is None:
        error_count = Counter()
    
    # Show progress indicator
    if show_progress and current_depth == 0:
        sys.stdout.write(".")
        sys.stdout.flush()
    
    # Check if we've reached max depth
    if current_depth > max_depth and max_depth >= 0:
        return 0
    
    total_size = 0
    try:
        # Get inode to detect loops with symlinks
        st = os.stat(path)
        inode = (st.st_dev, st.st_ino)
        
        # If we've seen this inode before, skip it to avoid loops
        if inode in visited:
            return 0
        
        visited.add(inode)
        
        # Iterate through directory entries
        for entry in os.scandir(path):
            try:
                # Skip hidden files/directories if not included
                if not include_hidden and entry.name.startswith('.'):
                    continue
                
                if entry.is_dir(follow_symlinks=False):
                    # Add size of the directory itself
                    total_size += get_file_size(entry.path)
                    # Recursively add size of contents
                    total_size += get_dir_size(
                        entry.path, visited, max_depth, current_depth + 1,
                        show_progress, show_warnings, include_hidden, error_count
                    )
                elif entry.is_file(follow_symlinks=False):
                    total_size += entry.stat().st_size
                # Handle symlinks if needed
                elif entry.is_symlink():
                    # Just count the link itself, not what it points to
                    total_size += get_file_size(entry.path)
            except (PermissionError, FileNotFoundError, OSError) as e:
                error_count[type(e).__name__] += 1
                if show_warnings:
                    print(f"Warning: Skipping {entry.path}: {e}", file=sys.stderr)
                continue
    except (PermissionError, FileNotFoundError, OSError) as e:
        error_count[type(e).__name__] += 1
        if show_warnings:
            print(f"Warning: Cannot access {path}: {e}", file=sys.stderr)
    
    return total_size


def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="List directories and files sorted by size."
    )
    parser.add_argument(
        "-d", "--max-depth", 
        type=int, 
        default=2,
        help="Maximum recursion depth for directory scanning (default: 2, use -1 for unlimited)"
    )
    parser.add_argument(
        "-w", "--warnings", 
        action="store_true", 
        help="Show permission warnings"
    )
    parser.add_argument(
        "-H", "--no-hidden", 
        action="store_true", 
        help="Skip hidden files and directories"
    )
    parser.add_argument(
        "-p", "--path", 
        type=str, 
        default=".",
        help="Directory to scan (default: current directory)"
    )
    parser.add_argument(
        "--no-progress", 
        action="store_true", 
        help="Don't show progress indicator"
    )
    
    return parser.parse_args()


def main():
    # Parse command-line arguments
    args = parse_args()
    
    # Get the directory to scan
    scan_dir = Path(args.path).expanduser().resolve()
    current_dir = scan_dir
    
    # Initialize lists for directories and files
    dir_info = []
    file_info = []
    
    # Error tracking
    error_count = Counter()
    
    print(f"Scanning {current_dir}...")
    print(f"Max depth: {args.max_depth if args.max_depth >= 0 else 'unlimited'}")
    
    start_time = time.time()
    
    try:
        # Scan entries in the current directory
        for entry in os.scandir(current_dir):
            try:
                # Skip hidden files/directories if requested
                if args.no_hidden and entry.name.startswith('.'):
                    continue
                    
                if entry.is_dir(follow_symlinks=False):
                    # Get directory size with progress indicator
                    size = get_dir_size(
                        entry.path, 
                        max_depth=args.max_depth,
                        show_progress=not args.no_progress,
                        show_warnings=args.warnings,
                        include_hidden=not args.no_hidden,
                        error_count=error_count
                    )
                    dir_info.append((size, entry.path, "[DIR]"))
                elif entry.is_file(follow_symlinks=False):
                    # Get file size
                    size = entry.stat().st_size
                    file_info.append((size, entry.path, "[FILE]"))
                elif entry.is_symlink():
                    # Handle symlinks - mark as special
                    target_path = os.readlink(entry.path)
                    if os.path.isdir(entry.path):
                        size = get_dir_size(
                            entry.path,
                            max_depth=args.max_depth,
                            show_progress=not args.no_progress,
                            show_warnings=args.warnings,
                            include_hidden=not args.no_hidden,
                            error_count=error_count
                        )
                        dir_info.append((size, entry.path, "[DIR-LINK→" + target_path + "]"))
                    else:
                        size = get_file_size(entry.path)
                        file_info.append((size, entry.path, "[FILE-LINK→" + target_path + "]"))
                
                if not args.no_progress:
                    sys.stdout.write(".")
                    sys.stdout.flush()
                    
            except (PermissionError, FileNotFoundError, OSError) as e:
                error_count[type(e).__name__] += 1
                if args.warnings:
                    print(f"Warning: Skipping {entry.path}: {e}", file=sys.stderr)
                continue
    except (PermissionError, FileNotFoundError, OSError) as e:
        print(f"Error: Cannot scan directory {current_dir}: {e}", file=sys.stderr)
        sys.exit(1)
    
    end_time = time.time()
    
    # Sort directories and files by size
    dir_info.sort(key=lambda x: x[0])
    file_info.sort(key=lambda x: x[0])
    
    # Print summary
    print("\nScan completed in {:.2f} seconds".format(end_time - start_time))
    
    # Print error summary if there were errors
    if sum(error_count.values()) > 0 and not args.warnings:
        print("\nEncountered errors (use --warnings to see details):")
        for error_type, count in error_count.items():
            print(f"  - {error_type}: {count}")
    
    # Print directories
    print("\n===== DIRECTORIES (smallest to largest) =====")
    for size, path, type_indicator in dir_info:
        print(f"{format_size(size):>10} {type_indicator:12} {path}")
    
    # Print files
    print("\n===== FILES (smallest to largest) =====")
    for size, path, type_indicator in file_info:
        print(f"{format_size(size):>10} {type_indicator:12} {path}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)

