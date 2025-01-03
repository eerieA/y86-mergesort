merge:                                # Args: rdi is first, rsi is last, rdx is mid
        mov     r10, rdi              # Copy first into r10, as initial_first for final copy
        mov     r9, rsi               # Copy last into r9, as final dest for final copy
        lea     rax, [rdx+4]          # second = mid + 1, this gonna be current second
        mov     r8, rdi               # Copy first into r8, this gonna be current first
        mov     ecx, OFFSET FLAT:temp # rcx = temp

        cmp     rdx, rdi              # Compare mid (rdx) and first (rdi)
        jnb     .L30                  # If mid >= first, first half not enough ele
        jmp     .L2                   # If not, start from first half
.L32: # fst_smaller
        add     r8, 4                 # Inc current first (r8) in first half
        mov     esi, edi              # Copy edi into esi (esi = *first)
.L4:  # copy_smaller                  # Copy *dest++ = *first++ or = *second++
        mov     DWORD PTR [rcx-4], esi          # Store the "smaller" element to temp
        cmp     rdx, r8               # Compare mid (rdx) and first (r8)
        jb      .L29                  # If mid < first, go copy all back
.L30: # compare                       # Main compare, with checking second half
        cmp     r9, rax               # Compare last (r9) with second (rax)
        jb      .L2                   # If last < second, second half not enough ele

        mov     edi, DWORD PTR [r8]             # edi = *first
        mov     esi, DWORD PTR [rax]            # esi = *second
        add     rcx, 4                # Inc dest pointer (dest++)

        cmp     esi, edi              # Compare *second and *first
        jge     .L32                  # If *second >= *first, first half is "smaller", go copy *first
        add     rax, 4                # If not, second half is "smaller", inc current second
        jmp     .L4                   # Go copy *second
.L9:  #copy_scd_loop                  # Copy second half leftovers
        mov     rdi, rcx              # rdi = temp
        mov     rsi, rax              # rsi = second
        movsd                         # Copy 4 bytes from temp (*%rcx) to ori (*%rax)
        mov     rax, rsi              # rax = second again to recover
        mov     rcx, rdi              # rcx = temp again to recover
.L29:                                 # Prep copying all back to original array
        cmp     r9, rax               # Compare last (r9) with second (rax)
        jnb     .L9                   # If last >= second, stop and cont copy second half
        cmp     r9, r10               # Compare last (r9) with initial_first (r10)
        jb      .L33                  # If last < initial_first, nothing, DONE
        sub     r9, r10               # If not, prep copying, r9 = last - first
        xor     eax, eax
        shr     r9, 2                 # r9 /= 4, r9 now holds number of elements
        lea     rcx, [4+r9*4]         # rcx = (num of ele + 1) * 4
.L13:  #copy_bk_loop                  # Loop part of .L29, copying everyone back
        mov     edx, DWORD PTR temp[rax]        # Load ele from temp, rax is current ptr in temp
        mov     DWORD PTR [r10+rax], edx        # Copy ele to ori array, r10+rax is current ptr in original
        add     rax, 4                # Increment current pointer in temp
        cmp     rcx, rax              # Compare temp (rcx) with current ptr
        jne     .L13                  # If temp != current ptr, repeat the copy loop
        ret                           # If temp == current ptr, all DONE
.L2:  #copy_fst_pre                   # Copy first half prep
        cmp     rdx, r8               # Compare mid (rdx) and first (r8)
        jb      .L29                  # If mid < first, go check second half
        mov     rdi, rcx              # If not, prep copy fist half leftovers, rdi = rcx (temp)
        mov     rsi, r8               # Copy first into rsi
.L8:  #copy_fst_8                     # Loop part of .L2
        movsd                         # Copy current ele from first half to temp
        cmp     rdx, rsi              # Compare mid (rdx) with first (rsi)
        jnb     .L8                   # If mid >= first, more elements to copy, loop

        sub     rdx, r8               # rdx = mid - first, remaining elements in first half
        shr     rdx, 2                # rdx /= 4
        lea     rcx, [rcx+4+rdx*4]    # Calculate new dest address, rcx = rcx + (rdx+1)*4
        jmp     .L29                  # Go see if copy second half
.L33:
        ret

mergesort.part.0:                  # Args: rsi is last, rdi is first
        mov     rax, rsi           # Copy last (rsi) to rax
        push    r12                # Save r12 (callee-saved register) on the stack
        sub     rax, rdi           # Calculate the size of the current segment: rax = rsi - rdi
        push    rbp                # Save rbp (callee-saved register) on the stack
        mov     rbp, rsi           # Copy last (rsi) in rbp
        sar     rax, 3             # rax = (rsi - rdi) / 8, now rax is num of elements
        push    rbx                # Save rbx (callee-saved register) on the stack
        mov     rbx, rdi           # Copy start (rdi) to rbx
        lea     r12, [rdi+rax*4]   # Compute the midpoint r12 = rdi + (rax * 4), dividing the array roughly in half

        cmp     rdi, r12           # Compare start (rdi) with the midpoint (r12)
        jb      .L38               # Jump to .L38 if start (rdi) < mid (r12) (go sort first half)
        
        lea     rdi, [r12+4]       # Set rdi to the next element after the midpoint (r12 + 4 bytes)
        cmp     rdi, rbp           # Compare rdi with the last (rbp)
        jb      .L39               # Jump to .L39 if mid + 1 (rdi) < last (rbp) (go sort second half)

.L36:  #prep_merge                 # Inner fall-through, both sorted, prep merging
        mov     rdx, r12           # Set rdx to the midpoint (r12) for merge()
        mov     rsi, rbp           # Set rsi to last (rbp) for merge()
        mov     rdi, rbx           # Set rdi to start (rbx) for merge()
        pop     rbx                # Restore the old value of rbx (popped from stack)
        pop     rbp                # Restore the old value of rbp (popped from stack)
        pop     r12                # Restore the old value of r12 (popped from stack)
        jmp     merge              # Jump to merge the two sorted halves

.L38:  #sort_left                  # Recursively sort the first half
        mov     rsi, r12           # Set rsi to the midpoint (r12) for the first half
        call    mergesort.part.0   # Recursively sort the first half
        lea     rdi, [r12+4]       # Set rdi to the next element after the midpoint (r12 + 4 bytes)
        cmp     rdi, rbp           # Compare rdi with the last (rbp)
        jnb     .L36               # If mid+1 (rdi) >= last (rbp) (no more ele to sort), jump to the merging phase (.L36)

.L39:  #sort_right                 # Recursively sort the second half
        mov     rsi, rbp           # Set rsi to the last (rbp) for the second half
        call    mergesort.part.0   # Recursively sort the second half
        jmp     .L36               # After sorting, jump to the merging phase (.L36)

mergesort:                         # Outer fall-through, continue or ret
        cmp     rdi, rsi           # Compare the start (rdi) and last (rsi) pointers
        jb      .L42               # If start < last, jump to start sorting (mergesort.part.0)
        ret                        # Otherwise, the array is already sorted, so return
.L42:
        jmp     mergesort.part.0

main:
        sub     rsp, 8
        mov     esi, OFFSET FLAT:array+48
        mov     edi, OFFSET FLAT:array
        call    mergesort.part.0
        xor     eax, eax
        add     rsp, 8
        ret
temp:
        .zero   52
array:
        .long   4
        .long   15
        .long   6
        .long   2
        .long   21
        .long   17
        .long   11
        .long   16
        .long   8
        .long   13
        .long   14
        .long   1
        .long   9