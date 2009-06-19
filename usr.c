#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#define MAXLINE 10000

double usr(double*, double*);
void chomp(char*);

int main() {
    typedef struct {
        int no;
        double descriptor[12];
    } Descriptor;

    Descriptor descriptors[MAXLINE];

    char 	line[MAXLINE];
    char*	elem;
    char*  	delims = ", ";
    int	dcount = 0;
    int 	p, q, r;
    double 	u;

    while(fgets(line, sizeof(line), stdin) != NULL) {
        Descriptor d;

        chomp(line);
        elem = strtok(line, delims);

        if (elem != NULL) {
            d.no = atoi(elem);
        } else {
            printf("Something wrong.\n");
            return 1;
        }

        int j = 0;
        while (elem != NULL) {
            elem = strtok(NULL, delims);

            if (elem != NULL) {
                d.descriptor[j] = atof(elem);
            }
            j++;
        }

        if (dcount < MAXLINE) {
            descriptors[dcount] = d;
            dcount++;
        } else {
            printf("You have more than %d lines!\n", MAXLINE);
        }
    }

    r = 0;
    for (p = 0; p < dcount - 1; p++) {
        for (q = p + 1; q < dcount; q++) {
            r++;
            u = usr(descriptors[p].descriptor, descriptors[q].descriptor);
            if (u > 0.8)
                printf("0\t%d\t%d\t%f\n", descriptors[p].no, descriptors[q].no, u);
        }
    }

    return 0;
}

double usr(double* a, double*b) {
    int	i = 0;
    double 	m_dist = 0.0;
    double	usr = 0.0;

    for(i=0; i < 12; i++) {
        m_dist += fabs(a[i] - b[i]);
    }

    usr = 1.0 / (1 + m_dist / 12.0);

    if ((usr > 1.0) || (usr < 0.0)) {
        printf("USR similarity cannot be %f\n", usr);
        exit(1);
    } else {
        return usr;
    }
}

void chomp (char* s) {
    int end = strlen(s) - 1;
    if (end >= 0 && s[end] == '\n') {
        s[end] = '\0';
    }
}

