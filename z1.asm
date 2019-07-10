assume cs:code1

dane1 segment

newline             db 0ah, 0dh, '$'                                        ; Nowa linia
plus                db 'plus $'
minus               db 'minus $'
multiply            db 'razy $'
zero                db "zero $"
one                 db "jeden $"
two                 db "dwa $"
three               db "trzy $"
four                db "cztery $"
five                db "piec $"
six                 db "szesc $"
seven               db "siedem $"
eight               db "osiem $"
nine                db "dziewiec $"
ten                 db "dziesiec $"
eleven              db 'jedenascie $'
twelve              db 'dwanascie $'
thirteen            db 'trzynascie $'
fourteen            db 'czternascie $'
fifteen             db 'pietnascie $'
sixteen             db 'szesnascie $'
seventeen           db 'siedemnascie $'
eighteen            db 'osiemnascie $'
nineteen            db 'dziewietnascie $' 
twenty              db 'dwadziescia $'
thirty              db 'trzydziesci $'
fourty              db 'czterdziesci $'
fifty               db 'piecdziesiat $'
sixty               db 'szescdziesiat $'
seventy             db 'siedemdizesiat $'
eighty              db 'osiemdziesiat $'
ninety              db 'dziewiecdziesiat $'
hundred             db 'sto $'
buffer              db 128,?, 128 dup(0)                                    ; Bufor dla stringów wpisanych
result              dw 0000h                                                ; Bufor wynikowy
begin_msg           db "KOLEJNOSC WYKONYWANIA DZIALAN NIE JEST ZACHOWANA", 0ah, 0dh, 0ah, 0dh, "Obslugiwany zakres wynikowy: -127:127", 0ah, 0dh, "Obslugiwane cyfry: 0:10" , 0ah, 0dh, "Obslugiwane dzialania: dodawanie, odejmowanie, mnozenie", 0ah, 0dh, 0ah, 0dh, "Wprowadz slowny opis dzialania:  $"
error_msg           db 'Nieprawidlowe dane $'         
range_error_msg     db 'liczba spoza zakresu wypisywania $'

dane1 ends

code1 segment
    
start1:
    ; Inicjowanie stosu
    mov sp, offset peak
    mov ax, seg peak
    mov ss, ax

    ; Wiadomosc powitalna            
    mov dx, offset begin_msg
    mov ax, seg begin_msg
    mov ds, ax
    mov ah, 9                                                               ; Wypisz stringa z ds:dx
    int 21h                                                                 ; Interrupt 21h dosowy, wypisz na std output

    ; Odczytanie dzialania    
    mov ax, seg buffer
    mov ds, ax   
    mov dx, offset buffer
    mov ah, 0ah                                                             ; Czytaj stringa
    int 21h
    
    ; Przetworzenie inputu
    xor bh, bh                                                              ; Zeruj bh
    mov bl, byte ptr ds:buffer[1]                                           ; [0] rozmiar bufora, [1] rozmiar wczytanego stringu
    mov byte ptr ds:buffer[bx+2], ' '                                       ; +2 dla rozmiarów i spacja "konczy" wyraz przy logice programu
    mov byte ptr ds:buffer[bx+3], '$'                                       ; Dodaj na koncu odczytanego stringa $
    
    ; Nowa linia
    mov ax, seg newline
    mov ds, ax   
    mov dx, offset newline
    mov ah, 9
    int 21h 
    
    mov bx, offset buffer + 2                                               ; Przygotuj bufor do liczenia, opusc rozmiary z dwoch pierwszych adresow
    
    xor cx, cx                                                              ; Wyzeruj cx, w cl będzie kod operacji
    mov cl, 01h                                                             ; Ustaw na dodawanie
                                                                            ; Wpisanie pierwszej liczby jest tym co zero + liczba, a bufor to zero na początku
    ; 01h addition
    ; 02h substract
    ; 03h multiply

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Glowna petla
main_loop:
    ; Usun whitespace'y z poczatku stringa
    call del_whitespace
    
    ; Sprawdz czy nie dolar (koniec)
    mov al, byte ptr ds:[bx]
    cmp al, '$'                                                             
    je wrong_input                                                          ; Skoncz jezeli wyrazenie niepoprawne (operator bez dwoch operandow)
    
    ; Parsuj string na liczbe
    call read_num                
    
    ; Obsluga bledow parsowania
    cmp al, 128
    je wrong_input                    

    ; Wybor dzialania
    cmp cl, 01h
    je adding
    
    cmp cl, 02h
    je substracting
    
    cmp cl, 03h
    je multiplying

handle_overflow:
    cmp word ptr ds:result, 128 
    jge overflow_err

    cmp word ptr ds:result, -127
    jl overflow_err
    

    ; Usun whitespace'y przed znakiem
    call del_whitespace
    
    ; Sprawdz czy nie dolar (koniec)
    mov al, byte ptr ds:[bx] 
    cmp al, '$'                                                             
    je the_end                                                                 ; Jesli tak to koncz
    
    ; Parsuj operator na dzialanie
    call read_operator            
    
    ; Obsluga bledow parsowania
    cmp cl, 128
    je wrong_input                      
                                
    ; Koniec petli glownej, wykonuj az do konca dzialania
    jmp main_loop
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ; Obsluga bledow i zakonczenie
    
; Koniec liczenia
the_end:
    mov ax, word ptr ds:result                                                  ; Wpisz wynik do ax
    call print_result_word                                                      ; Wypisz slownie liczbe z ax
    
; Wyjscie z programu
exit:                          
    mov	ah, 4ch  
	int	021h    
	
; Zakonczenie programu z bledem inputu
wrong_input:
    mov ax, seg error_msg
    mov ds, ax
	mov dx, offset error_msg
	mov ah, 9
	int 21h
	jmp exit

; Zakonczenie programu z bledem overflow
overflow_err:
    mov ax, seg range_error_msg
    mov ds, ax
    mov dx, offset range_error_msg
	mov ah, 9
	int 21h
	jmp exit
	
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Obsluga obliczen

; Dodawanie
adding:
    add word ptr ds:result, ax
    jmp handle_overflow

; Odejmowanie
substracting:
    sub word ptr ds:result, ax
    jmp handle_overflow

; Mnozenie
multiplying:
    push dx                                                                     ; Zabezpiecz dx
    mov cl, al                                                                  ; Wpisz do cl liczbe przez ktora mnozymy
    mov al, byte ptr ds:result                                                  ; Do ax wpisz result
    imul cl                                                                     ; Pomnoz, al zawsze drugim argumentem
    mov word ptr ds:result, ax                                                  ; Zapisz wynik
    pop dx
    jmp handle_overflow
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Obsluga/usuwanie whitespace'ow 

; Usuwanie whitespace z początku ds:bx  
del_whitespace:
    
    mov ah, byte ptr ds:[bx]
    mov al, 9
    cmp al, ah                                                                  ; Sprawdz tabulacje, bez zapisania wyniku
    je skip_whitespace                                                          ; Jesli rowne idz dalej
    
    mov ah, byte ptr ds:[bx]
    mov al, 20h
    cmp al, ah                                                                  ; Sprawdz spacje
    je skip_whitespace                                                          ; Jesli rowne idz dalej
    ret 

skip_whitespace:
    inc bx                                                                      ; Przejdz na nastepny bit
    jmp del_whitespace                                                          ; Az do skutku
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ; Sprawdzanie poprawnosci wpisanego wyrazenia

; Czy ds:bx zgadza sie ze wzorcem pod ds:ax (wynikiem jest odpowiednia flaga ZF)
checkword:                                                            
    push bx                                                                     ; Zachowaj wskaznik na poczatek stringa (przywraca w przypadku niezgodnosci)
    mov bp, ax                                                                  ; Wpisz do bp adres wzorca

; Petla sprawdzajaca bajt po bajcie     
checkloop:        
    mov al, byte ptr [bx]                                                       ; Pierwszy bajt stringa do porownania
    mov ah, byte ptr ds:[bp]                                                    ; Pierwszy bajt wzorca
    
    cmp ah, 20h                                                                 ; Sprawdzam czy spacja
    je check_if_end
  
    ; Sprawdzenie bajtow
    cmp al, ah                                                                     
    jne endfunc_checkword_wrong                                                 ; Jak nie to blad

    ; Inkrementacja bajtow i powtorzenie sprawdzania 
    inc bx
    inc bp
    jmp checkloop
    
; Sprawdz czy koniec (whitespace)
check_if_end:
    cmp al, 20h
    je endfunc_checkword_good
    cmp al, 9
    je endfunc_checkword_good

    jmp endfunc_checkword_wrong

; Niepasujacy wzorzec
endfunc_checkword_wrong:
    pop bx                                                                      ; Przywroc wskaznik na sprawdzane wyrazenie
    ret                                       
    
; Pasujacy wzorzec
endfunc_checkword_good:
    add sp, 2                                                                   ; Sciagnij wartosc ze stosu, bo juz jej nie potrzebujemy (2 bajty bo slowo)
    cmp al, al                                                                  ; Ustaw zero flag (poprzednia operacja zmienila)
    ret
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ; Pseudo abstrakcja do sprawdzania wyrazen

; Odczytywanie liczb
read_num:                                                                       ; Czyta z ds:dx i zwraca w ax
    
    ; Zachowanie cx przed zniszczeniem
    push cx
    
    ; Sprawdzanie ze wzorcem
    mov ax, offset zero  
    call checkword
    mov ax, 0
    je endfunc_read_num
    
    mov ax, offset one  
    call checkword
    mov ax, 1
    je endfunc_read_num
    
    mov ax, offset two  
    call checkword
    mov ax, 2
    je endfunc_read_num     
    
    mov ax, offset three  
    call checkword
    mov ax, 3
    je endfunc_read_num
    
    mov ax, offset four  
    call checkword
    mov ax, 4
    je endfunc_read_num
    
    mov ax, offset five  
    call checkword
    mov ax, 5
    je endfunc_read_num
    
    mov ax, offset six  
    call checkword
    mov ax, 6
    je endfunc_read_num
    
    mov ax, offset seven  
    call checkword
    mov ax, 7
    je endfunc_read_num
    
    mov ax, offset eight  
    call checkword
    mov ax, 8
    je endfunc_read_num
                         
    ; mov ax, seg nine
    ; mov ds, ax                     
    mov ax, offset nine   
    call checkword
    mov ax, 9
    je endfunc_read_num 
    
    mov ax, offset ten  
    call checkword
    mov ax, 10
    je endfunc_read_num                      

    ; Ustawiam 128 jako nieprawidlowa wartosc dla obslugi bledow
    mov ax, 128
    
; Sprawdz czy blad
endfunc_read_num:
    cmp ax, 128
    je wrong_input

    ; Przywroc cx do stanu pierwotnego
    pop cx
    ret                           

; Parsowanie operatora 
read_operator:                                                                  ; Parsuje z ds:dx zwraca w cl
    ; Sprawdzanie ze wzorcem
    mov ax, offset plus  
    call checkword
    mov cl, 01h
    je endfunc_read_operator

    mov ax, offset minus  
    call checkword
    mov cl, 02h
    je endfunc_read_operator

    mov ax, offset multiply  
    call checkword
    mov cl, 03h
    je endfunc_read_operator

    ; Bledny operator
    mov cl, 128

; Sprawdz czy blad
endfunc_read_operator:
    cmp cl, 128
    ret
               
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Wypisywanie wyniku

; Wypisanie slowa wynikowego z ax (-127 do 127)
print_result_word:
    ; Zachowanie wartosci rejestrow dla bezpieczenstwa
    push ax
    push bx
    push cx
    push dx
    
    ; Sprawdzenie czy ujemne i ewentualny skok
    cmp ax, 0
    jnl print_abs                                                               ; Jak ax < 0 to zmien znak i dopisz minus
    
    ; Wartosc bezwzgledna i wypisanie minusa
    neg ax                                                                      ; ax = -ax
    push ax                                                                     ; Push ax bo int21h wymaga zmiany ax
    mov dx, offset minus
    mov ah, 9                                                                   ; Wyswietl minus
    int 21h
    pop ax                                                                      ; Przywroc ax poprzednie   
    
; Wypisz liczbe slownie, czesc "dodatnia"
print_abs:
    ; Dla ax >= 100 osobna funkcji
    cmp ax, 100 
    jge print_sto
            
    xor dx, dx                                                                  ; Wyzeruj dx dla bezpieczenstwa     

    ; Dzielenie przez 10        
    mov bx, 10
    div bx                                                                      ; Dzielimy przez bx (10), wynik w ax, reszta w dx

    ; Przechowanie reszty z dzielenia   
    push dx
    
    ; Sprawdzenie czy jednocyfrowa
    cmp al, 0
    je single_digit_print
    
    ; Sprawdzenie czy nastoletnia
    cmp al, 1
    je teen_print
    
    ; Przechowac liczbe jednosci i wybierz oraz wypisz czesc dziesiatek dla wiekszych niz 19 
    cmp al, 2
    mov dx, offset twenty
    je double_dig_print                  
    
    cmp al, 3
    mov dx, offset thirty
    je double_dig_print
    
    cmp al, 4
    mov dx, offset fourty
    je double_dig_print
    
    cmp al, 5
    mov dx, offset fifty
    je double_dig_print
    
    cmp al, 6
    mov dx, offset sixty
    je double_dig_print
    
    cmp al, 7
    mov dx, offset seventy
    je double_dig_print
    
    cmp al, 8
    mov dx, offset eighty
    je double_dig_print
    
    cmp al, 9
    mov dx, offset ninety
    je double_dig_print                   
    
    ; Skocz do konca
    jmp print_num_end
    
; Wypisz liczbe jednostek
single_digit_print:      
    pop dx                                                                      ; Pobierz reszte z dzielenia z zestosu
    mov ax, dx                                                                  ; Wrzuc ja do ax
    
    ; Wybierz cyfre jednosci
    cmp al, 0
    mov dx, offset zero
    je digit_printout

    cmp al, 1
    mov dx, offset one
    je digit_printout
    
    cmp al, 2
    mov dx, offset two
    je digit_printout
    
    cmp al, 3
    mov dx, offset three
    je digit_printout
    
    cmp al, 4
    mov dx, offset four
    je digit_printout
    
    cmp al, 5
    mov dx, offset five
    je digit_printout
    
    cmp al, 6
    mov dx, offset six
    je digit_printout
    
    cmp al, 7
    mov dx, offset seven
    je digit_printout
    
    cmp al, 8
    mov dx, offset eight
    je digit_printout
    
    cmp al, 9
    mov dx, offset nine
    je digit_printout
    
; Wypisz cyfre
digit_printout:
    mov ah, 9
    int 21h
    jmp  print_num_end 
    
; Wybierz i wypisz nastolatki
teen_print:
    pop dx                                                                      ; Pobierz reszte z dzielenia z zestosu
    mov ax, dx                                                                  ; Wrzuc ja do ax
    
    ; Wybierz cyfre "teen"
    cmp al, 0
    mov dx, offset ten
    je digit_printout

    cmp al, 1
    mov dx, offset eleven
    je digit_printout
    
    cmp al, 2
    mov dx, offset twelve
    je digit_printout
    
    cmp al, 3
    mov dx, offset thirteen
    je digit_printout
    
    cmp al, 4
    mov dx, offset fourteen
    je digit_printout
    
    cmp al, 5
    mov dx, offset fifteen
    je digit_printout
    
    cmp al, 6
    mov dx, offset sixteen
    je digit_printout
    
    cmp al, 7
    mov dx, offset seventeen
    je digit_printout
    
    cmp al, 8
    mov dx, offset eighteen
    je digit_printout
    
    cmp al, 9
    mov dx, offset nineteen
    je digit_printout

; Wypisz liczbe dziesiatek
double_dig_print:
    mov ah, 9
    int 21h

    ; Pobierz reszte z dzielenia i sprawdz czy nie jest zerem (brak wypisywania pelnych dziesiatek jako 'liczba zero')
    pop dx
    cmp dx, 0
    je print_num_end                                                            ; Jak jest zerem to skoncz
    ; Jesli nie, obsluz jednosci
    push dx
    jmp single_digit_print

; Wypisywanie >= 100
print_sto:
    ; Wypisz sto
    push ax                                                                     ; Zachowaj ax
    mov dx, offset hundred
    mov ah, 9          
    int 21h
    pop ax                                                                      ; Przywroc ax
    sub ax, 100                                                                 ; Odejmij 100
    je print_num_end

    ; Wroc do wypisania pozostalej czesci liczby
    jmp print_abs
    
; Zakoncz wypisywanie
print_num_end:
    ; Przywrocenie rejestrow
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret    
	     
ret

code1 ends

stos1 segment stack
        dw 200 dup(?)
peak    dw ?

stos1 ends

end start1


