import argparse
import subprocess
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Little Sokoban Test Runner")
    parser.add_argument(
        "--scenario",
        type=int,
        choices=[1, 2, 3],
        default=1,
        help="Select the test scenario (1, 2, or 3)"
    )
    parser.add_argument(
        "--monitor",
        action="store_true",
        help="Run in headful mode to visually monitor the execution"
    )
    parser.add_argument(
        "--godot-path",
        type=str,
        default=r"D:\Godot\Godot.exe",
        help="Path to the Godot Engine executable"
    )
    parser.add_argument(
        "--level",
        type=int,
        default=1,
        help="Start Stage number (1-50) for Scenario 1"
    )
    
    args = parser.parse_args()
    
    # Verify Godot path exists
    if not os.path.exists(args.godot_path):
        print(f"Error: Godot executable not found at '{args.godot_path}'.", file=sys.stderr)
        print("Please specify a valid path using the --godot-path option.", file=sys.stderr)
        sys.exit(1)
        
    print(f"--- Little Sokoban Test Automation Wrapper ---")
    print(f"Godot Path: {args.godot_path}")
    print(f"Scenario: {args.scenario}")
    if args.scenario == 1:
        print(f"Start Level: {args.level}")
    print(f"Monitor Mode: {'Headful (Visual)' if args.monitor else 'Headless'}")
    
    # Base command arguments for Godot
    cmd = [args.godot_path, "--path", "."]
    
    if not args.monitor:
        cmd.append("--headless")
        
    # Append user arguments after the '--' delimiter
    cmd.extend(["--", "--test-mode", f"--scenario={args.scenario}", f"--level={args.level}"])
    
    # Configure timeouts depending on the scenario
    # Scenario 1 takes longer since it solves 50 stages (0.12s per step)
    timeout_seconds = 600 if args.scenario == 1 else (120 if args.scenario == 2 else 30)
    print(f"Timeout limit set to: {timeout_seconds} seconds")
    print(f"Running command: {' '.join(cmd)}")
    print("---------------------------------------------")
    
    try:
        # Run Godot subprocess and pipe outputs
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        # Read stdout line-by-line in real time
        for line in process.stdout:
            print(line, end="")
            
        process.wait(timeout=timeout_seconds)
        
        exit_code = process.returncode
        print("---------------------------------------------")
        if exit_code == 0:
            print(f"Success: Test Scenario {args.scenario} Completed Successfully!")
            sys.exit(0)
        else:
            print(f"Failure: Test Scenario {args.scenario} failed with exit code {exit_code}.", file=sys.stderr)
            sys.exit(exit_code)
            
    except subprocess.TimeoutExpired:
        print("\n---------------------------------------------", file=sys.stderr)
        print(f"Failure: Test Scenario {args.scenario} exceeded the timeout limit of {timeout_seconds}s.", file=sys.stderr)
        process.kill()
        sys.exit(1)
    except Exception as e:
        print(f"\nError executing Godot process: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
