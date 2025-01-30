#include <iostream>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <chrono> 
using namespace std;

void checkArrays(int arr1[], int arr2[], int N) {
    int res = 0;
    for (int i = 0; i < N; i++) {
        res = (arr1[i] ^ arr2[i]);
    }

    if (res == 0) {
        cout << "Same" << endl;
    } else {
        cout << "Not Same" << endl;
    }
}
int find(int parent[], int x) {
    if (parent[x] == x) return x;
    return parent[x] = find(parent, parent[x]);
}

void unite(int parent[], int rank[], int x, int y) {
    int rootX = find(parent, x);
    int rootY = find(parent, y);
    if (rootX != rootY) {
        if (rank[rootX] > rank[rootY]) {
            parent[rootY] = rootX;
        } else if (rank[rootX] < rank[rootY]) {
            parent[rootX] = rootY;
        } else {
            parent[rootY] = rootX;
            rank[rootX]++;
        }
    }
}

__global__ void list_ranking(int* d_vals1,int* d_vals2,int* d_rank1,int* d_rank2,int n)
{
    int tid=blockIdx.x*blockDim.x+threadIdx.x;
    if(tid<n){
        //printf("%d , %d",d_rank1[tid],d_vals1[tid]);
        d_rank2[tid]=d_rank1[tid]+d_rank1[d_vals1[tid]];
        d_vals2[tid]=d_vals1[d_vals1[tid]];

    }
}

__global__ void d_parent(int d_N,int* d_final_rank,int* d_parent,int* d_arr1,int* d_arr2,int d_root)
{
    
    int tid = (blockIdx.x * blockDim.x)+threadIdx.x ;

    // if(tid==0)
    // {
    //         printf("Rank is below at GPU\n");
    // for(int i=0;i<2*d_N-2;i++)
    // {
    //     printf("%d ",d_final_rank[i]);
    // }
    // printf("\nArr1 in gpu \n");
    //     for(int i=0;i<2*d_N-2;i++)
    // {
    //     printf("%d ",d_arr1[i]);
    // }
    // printf("\nArr2 in gpu \n");
    //     for(int i=0;i<2*d_N-2;i++)
    // {
    //     printf("%d ",d_arr2[i]);
    // }
    // printf("\n");
    // }
    //  Compute the parent array
    if (tid <d_N) {
        //printf("Tid = %d",tid);printf("\n");
        int edge1 = tid;
        int edge2 = tid + d_N - 1;
        // if(tid==0)
        // {
        //     printf("Edge 1 is %d and edge 2 is %d \n",edge1,edge2);
        // }

        if (d_final_rank[edge1] > d_final_rank[edge2]) {
            
            d_parent[d_arr2[tid]] = d_arr1[tid];
            //printf("parent of %d  is %d \n",d_arr2[tid],d_arr1[tid]);
        } 
        else {
            d_parent[d_arr1[tid]] = d_arr2[tid];
           // printf("parent of %d  is %d \n",d_arr2[tid],d_arr1[tid]);
        }
    }
    
    if (tid == 0) {
        d_parent[d_root] = -1;
    }



    // if(tid==1)
    // {
    //     printf("Gpu parent \n");
    //     for(int i=0;i<d_N;i++)
    //     {
    //         printf("%d ",d_parent[i]);
    //     }   
    //     printf("\n");
        
    // }
}
__global__ void d_Parallel_Eulerian2(int* d_succ, int d_edgeCount, int* d_vertex, int* d_edges, int d_root, int d_N) 
{
    int tid = (blockIdx.x * blockDim.x)+threadIdx.x ;
    if(tid<d_N)
    {
        int no_of_neighbours=d_vertex[tid+1]-d_vertex[tid],u,v,succ_val,jump;
        int neighbours_copy=no_of_neighbours,i=0;
       // printf("Tid =%d i have %d neighbours\n",tid,no_of_neighbours);
        while(i<no_of_neighbours)
        {
            u=d_edges[d_vertex[tid]+i];
            v= (u + d_edgeCount) % (2 * d_edgeCount);
           /// printf("Tid =%d calculated u=%d its twin is v=%d\n",tid,u,v);
            if(d_vertex[tid+1]>d_vertex[tid]+i+1)
            {
                succ_val=d_edges[d_vertex[tid]+i+1];
               /// printf("succseor of %d = %d,by tid=%d by if\n",v,succ_val,tid);
                d_succ[v]=succ_val;

            }
            else{
                succ_val=d_edges[d_vertex[tid]];
                //succ_val=d_edges[((d_vertex[tid+1]-d_vertex[tid]+i))+d_vertex[tid]];
                d_succ[v]=succ_val;
               // printf("succseor of %d = %d,by tid=%d by else\n ",v,succ_val,tid);
            }
            i++;
        }
    }

}
__global__ void d_Parallel_Eulerian1(int* d_succ, int d_edgeCount, int* d_vertex, int* d_edges, int d_root, int d_N) 
{
    int tid = (blockIdx.x * blockDim.x)+threadIdx.x ;
    // if(tid==1)
    //     printf("Hi\n");

    // successor array 
    if (tid < d_N) {
        int vertex_val = 1;
        while (tid >= d_vertex[vertex_val] && vertex_val < d_N) {
            vertex_val++;
        }
       // printf("Vertex val=%d by tid %d\n",vertex_val,tid);
        int x = d_edges[d_vertex[tid]];
        int succ_val = (x + d_edgeCount) % (2 * d_edgeCount);
        
        if (tid + 1 == d_vertex[vertex_val]) {
            d_succ[succ_val] = d_edges[d_vertex[vertex_val - 1]];
        } else {
            d_succ[succ_val] = d_edges[tid + 1];
        }
    }
    // if(tid==1)
    //     printf("Succersor[10] from gpu %d\n",d_succ[10]);
    //__syncthreads();

    // Step 2: Compute the final rank array


    // if (tid == 0) {
    //     int prev = d_edges[d_vertex[d_root]];
    //     d_final_rank[prev] = 0;
        
    //     for (int i = 1; i < 2 * d_edgeCount; i++) {
    //         d_final_rank[d_succ[prev]] = i;
    //         prev = d_succ[prev];
    //     }
    // }


    //__syncthreads();
    // if(tid==1)
    // {
    //     printf("Gpu rank \n");
    //     for(int i=0;i<d_N;i++)
    //     {
    //         printf("%d ",d_final_rank[i]);
    //     }   
    //     printf("\n");
        
    // }


}






void Serial_Eulerian(int* succ,int edgeCount,int* vertex,int* edges,int* final_rank,int root,int N,int* arr1,int* arr2,int* parent)
{
    int vertex_val=1,edge1,edge2;

    for(int i=0;i<2*edgeCount;i++)
    {
        if(i>=vertex[vertex_val])
        {
            vertex_val++;
        }
        int x=edges[i];
        int succ_val= (x+edgeCount)%((2*edgeCount));
        
        if (i + 1 == vertex[vertex_val]) {
        succ[succ_val] = edges[vertex[vertex_val - 1]];
        //cout << "Succ = " << succ_val << " val= " << edges[vertex[vertex_val - 1]] << " Calculatedby = " << i << " vertex val = " << vertex_val << endl;
        }

         else
        {
            //cout << "Succ = " << succ_val << " val= " << edges[i+1] << "Calculatedby = " << i << endl;
            succ[succ_val]=edges[i+1];
        }
            
        //cout << " "<<succ_val << "=" << edges[i+1] << endl;
    }    

    // cout << endl;cout << endl << "successor serial" << endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     cout << " "<< succ[i] ;
    // }
    int prev=edges[vertex[root]];
    final_rank[prev]=0;
    // cout <<endl << "First Child " << root<< "First Edge Number "<<prev<<endl;

    for(int i=1;i<2*edgeCount;i++)
    {
        
        final_rank[succ[prev]]=i;
        prev=succ[prev];
    }

    // cout << endl;cout << endl << "Final Rank " << endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     cout << " "<< final_rank[i] ;
    // }
    // cout << endl;


    for(int i=0;i<N;i++)
    {
        edge1=i;
        edge2=i+N-1;
        if(final_rank[edge1]<final_rank[edge2])
        {
            parent[arr2[i]]=arr1[i];
        }
        else{
            parent[arr1[i]]=arr2[i];
        }
    }    

    parent[root]=-1;

    // cout<< endl << "Parent List After Eulerian Serial" << endl;

    // for (int i = 0; i < N; i++)
    // {
    //     printf("%d ",parent[i]);
    // }
    // cout << endl;



}

void createCSR(int N,int arr1[],int arr2[],int edgeCount,int* vertex,int* edges)
{
    int index;

    for (int i = 0; i < N+1; i++) {
    vertex[i] = 0;
    }

    for (int i = 0; i < (2*N)-2; i++){
        vertex[arr1[i]+1]++;

    } 

    //PREFIX SUM BELOW

    for (int i = 1; i < N+1; i++) {
    vertex[i] += vertex[i - 1];
    }

    for (int i = 0; i < 2*edgeCount+2; i++) {
    edges[i] = -1;
    }

    for(int i=0;i<2*N-2;i++)
    {
        index= vertex[arr1[i]];
        while(edges[index]!=-1)
        {
            index++;
        }
        edges[index]=i;
    }
    // cout<<"vertexs " << endl;

    // for (int i = 0; i <N+1; i++){
    //     printf("%d ",vertex[i]);

    // }cout << endl;


    // cout<<"Edges " << endl;

    // for (int i = 0; i <2*edgeCount; i++){
    //     printf("%d ",edges[i]);

    // }cout << endl;




    



}


void generateTree(int N, int root,int* arr1,int* arr2,int* parentArray,int* parent) {


    //int* arr1 = new int[2*(N - 1)];          
    //int* arr2 = new int[2*(N - 1)];
    //int* parentArray = new int[N]; 
    //int* parent = new int[N];  
    //int* rank = new int[N]();
    int* rank = new int[N]();



    for (int i = 0; i < N; i++) {
        parent[i] = i;
        parentArray[i] = -1;
    }

    srand(time(0));


    int edgeIndex = 0;
    int firstChild = (root + 1) % N;
    arr1[edgeIndex] = root;
    arr2[edgeIndex] = firstChild;
    arr1[edgeIndex+(N-1)] = firstChild;
    arr2[edgeIndex+(N-1)] = root;
    parentArray[firstChild] = root;
    unite(parent, rank, root, firstChild);
    edgeIndex++;


    for (int i = 0; i < N; i++) {
        if (i == root || i == firstChild) continue; 

        int parentVertex = rand() % N;
        while (find(parent, i) == find(parent, parentVertex) || parentArray[i] != -1 || parentVertex == i) {
            parentVertex = rand() % N; 
        }

        arr1[edgeIndex] = parentVertex;
        arr2[edgeIndex] = i;
        arr1[edgeIndex+(N-1)] = i;
        arr2[edgeIndex+(N-1)] = parentVertex;
        parentArray[i] = parentVertex;
        unite(parent, rank, parentVertex, i);
        edgeIndex++;
    }


    // cout << "Edge Arrays:" << endl;
    // cout << "arr1: ";
    // for (int i = 0; i < 2*(N-1); i++) cout << arr1[i] << " ";
    // cout << endl;

    // cout << "arr2: ";
    // for (int i = 0; i < 2*(N - 1); i++) cout << arr2[i] << " ";
    // cout << endl;


    // cout << "Parent Array Original" << endl;
    // for (int i = 0; i < N; i++) {
    //     cout << parentArray[i] << " ";
    // }
    // cout << endl;


    //generateCSR(N, arr1, arr2, N - 1);

    free(rank);



}

int main() {
    int N, root;
    cout << "Enter the number of vertices: ";
    cin >> N;
    cout << "Enter the root vertex: ";
    cin >> root;


    int* arr1 = new int[2*(N - 1)];          
    int* arr2 = new int[2*(N - 1)];
    int* actual_parent = new int[N]; 
    int* parent = new int[N]; 

    int edgeCount=N-1;

    generateTree(N, root,arr1,arr2,actual_parent,parent);

    int* vertex= new int [N+2];
    int* edges = new int[2*edgeCount] ();
    int* final_rank_serial=new int[2*edgeCount] ();
    int* final_rank=new int[2*edgeCount] ();

    // cout <<"Arr1 " << endl;
    // for(int i=0;i<(2*(N-1));i++)
    // {
    //     cout << arr1[i]<< " ";
    // }
    // cout << endl;

    // cout <<"Arr2 " << endl;
    // for(int i=0;i<(2*(N-1));i++)
    // {
    //     cout << arr2[i]<< " ";
    // }
    // cout << endl;    


    createCSR(N,arr1,arr2,edgeCount,vertex,edges);

    int* succ_serial = new int[2 * edgeCount]();
    int* succ = new int[2 * edgeCount]();
    int* serial_euiler_parent= new int [N];
    int* parallel_euiler_parent= new int [N];
 
    
    auto start_serial = std::chrono::high_resolution_clock::now();
    Serial_Eulerian(succ_serial, edgeCount, vertex, edges, final_rank_serial, root, N, arr1, arr2, serial_euiler_parent);
    auto end_serial = std::chrono::high_resolution_clock::now();
    auto duration_serial = std::chrono::duration_cast<std::chrono::nanoseconds>(end_serial - start_serial);
    long long serial_time = duration_serial.count();  // Time in milliseconds
    std::cout << "Serial Execution Time: " << serial_time << " ms" << std::endl;


    int* d_succ1 = nullptr;         // Device pointer for successor array
    int* d_succ2 = nullptr;
    int* d_edgeCount = nullptr;    // Device pointer for edge count
    int* d_vertex = nullptr;       // Device pointer for vertex array
    int* d_edges = nullptr;        // Device pointer for edges array
    int* d_parallel_euiler_parent= nullptr;
    int* d_final_rank1=nullptr;
    int* d_final_rank2=nullptr;
    int* d_arr1=nullptr;
    int* d_arr2=nullptr;
    int* h_parallel_euiler_parent = new int[N];  // Allocate memory for host array

    cudaFree(0);


    if(cudaMalloc((void **)&d_succ1,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_suc");
    if(cudaMalloc((void **)&d_succ2,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_suc");
    if(cudaMalloc((void **)&d_parallel_euiler_parent,N*sizeof(int))!=cudaSuccess) printf("Error allocationg parallel_euiler_parent");
    if(cudaMalloc((void **)&d_edgeCount,1*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edgeCount");
    if(cudaMalloc((void **)&d_vertex,(N+2)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_vertex");
    if(cudaMalloc((void **)&d_edges,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_final_rank1,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_final_rank2,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_arr1,2*(N-1)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_arr2,2*(N-1)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");


    cudaMemcpy(d_succ1, succ, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_parallel_euiler_parent, parallel_euiler_parent, N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_vertex, vertex, (N + 2) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_edges, edges, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_final_rank1, final_rank, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_arr1, arr1, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_arr2, arr2, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    
    //cudaMemcpy(&d_edgeCount,edgeCount,1*sizeof(int),cudaMemcpyHostToDevice);
    




    //Parallel_Eulerian(succ,edgeCount,vertex,edges,final_rank,root,N,arr1,arr2,parallel_euiler_parent);

    cudaEvent_t start_parallel, stop_parallel;
    cudaEventCreate(&start_parallel);
    cudaEventCreate(&stop_parallel);

    cudaEventRecord(start_parallel);
    
    int blockSize = 1024;
    int numBlocks = ((2 * edgeCount) + blockSize - 1) / blockSize;  // Calculate blocks for kernel
    d_Parallel_Eulerian2<<<numBlocks, blockSize>>>(d_succ1, edgeCount, d_vertex, d_edges, root, N);
    cudaDeviceSynchronize();
    cudaMemcpy(succ,d_succ1,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);

    //     cout << endl;cout << endl << "successor parallel" << endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     cout << " "<< succ[i] ;
    // }cout<<endl;

  // In CSR Each vertex has its outgoing edge


    // cout<<"Printting csr"<<endl;
    // for(int i=0;i<=N;i++)
    // {
    //     cout<< vertex[i] << " ";
    // }cout<<endl;
    // for(int i=0;i<=2*edgeCount;i++)
    // {
    //     cout<< edges[i] << " ";
    // }cout<<endl<< endl;
    
    int last_edge=edges[vertex[root+1]-1];
    last_edge=last_edge+N-1;
    // cout<<"Last edge = "<<last_edge << endl;

    for(int i=0;i<2*edgeCount;i++)
    {
        final_rank[i]=1;
        // if(i==edges[vertex[root]])
        //     final_rank[i]=0;
    }
    int p=edges[vertex[root]];
     succ[last_edge] =last_edge ;
     final_rank[last_edge]=0;

    // cout << endl;cout << endl << "successor parallel" << endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     cout << " "<< succ[i] ;
    // }cout<<endl;

    //     cout << endl;cout << endl << "Rank before loop" << endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     cout << " "<< final_rank[i] ;
    // }cout<<endl;


    int loop=log(N),z;
    loop=loop+10;z=loop;

    cudaMemcpy(d_final_rank1,final_rank,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(d_succ1,succ,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);

    for(int i=0;i<loop;i++)
    {
        if(i%2==0)
        {
            list_ranking<<<numBlocks,blockSize>>>(d_succ1,d_succ2,d_final_rank1,d_final_rank2,2*edgeCount);

        }
        else
        {
            list_ranking<<<numBlocks,blockSize>>>(d_succ2,d_succ1,d_final_rank2,d_final_rank1,2*edgeCount);
        }
        cudaDeviceSynchronize();
    }
    /*while(loop--)
    {
    //z++;
    cudaMemcpy(d_final_rank1,final_rank,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(d_succ1,succ,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);

    list_ranking<<<numBlocks,blockSize>>>(d_succ1,d_succ2,d_final_rank1,d_final_rank2,2*edgeCount,0);

    cudaDeviceSynchronize();
    cudaMemcpy(final_rank,d_final_rank2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);
    cudaMemcpy(succ,d_succ2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);

    cout<< "Rank is below at iteration "<< loop-z<<endl;
    for(int i=0;i<2*edgeCount;i++)
    {
        printf("%d ",final_rank[i]);
    }
    cout<<endl;
    }*/
    cudaMemcpy(final_rank,d_final_rank2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);
    cudaMemcpy(succ,d_succ2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);

    // cout<< "Rank is below at host"<<endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     printf("%d ",final_rank[i]);
    // }
    // cout<<endl;
    // cout<< "Succ is below for itr "<<loop-4<<endl;
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     printf("%d ",succ[i]);
    // }
    // cout<<endl;

    // //cudaDeviceSynchronize();
    // }
    // for(int i=0;i<2*edgeCount;i++)
    // {
    //     printf("%d ",final_rank[i]);
    // }

    // cout << endl << "Parallel GPU output" << endl;

    // for(int i=0;i<N;i++)
    // {
    //     printf("%d ",h_parallel_euiler_parent[i]);
    // }
    // cout << endl<< "Serial Output" << endl;

    // for(int i=0;i<N;i++)
    // {
    //     printf("%d ",serial_euiler_parent[i]);
    // }
    // cout << endl;
   // d_parent(int d_N,int* d_final_rank,int* d_parent,int* d_arr1,int* d_arr2,int d_root);
    cudaMemcpy(d_arr1, arr1, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_arr2, arr2, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_final_rank1,final_rank,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);
    d_parent<<<numBlocks, blockSize>>>(N,d_final_rank1,d_parallel_euiler_parent,d_arr1,d_arr2,root);
    cudaDeviceSynchronize();
    cudaMemcpy(parallel_euiler_parent,d_parallel_euiler_parent,N*sizeof(int),cudaMemcpyDeviceToHost);
    cudaEventRecord(stop_parallel);
    cudaEventSynchronize(stop_parallel);

    float parallel_time_float;
    cudaEventElapsedTime(&parallel_time_float, start_parallel, stop_parallel);  // Time in milliseconds

    // Convert to nanoseconds
    long long parallel_time_ns = static_cast<long long>(parallel_time_float * 1e6);  // 1 ms = 1e6 ns

    std::cout << "Serial Execution Time: " << serial_time << " ms" << std::endl;

    std::cout << "Parallel Execution Time: " << parallel_time_ns << " ns" << std::endl;


    checkArrays(actual_parent,serial_euiler_parent,N);
    checkArrays(actual_parent,parallel_euiler_parent,N);
    //cout<<"Loop value =" << z<<endl;
    //checkArrays(actual_parent,h_parallel_euiler_parent,N);

    



    // free(edges);
    free(arr1);
    free(arr2);
    free(parent);
    free(actual_parent);

    // free(final_rank);
    free(succ);
    free(serial_euiler_parent);
    free(parallel_euiler_parent);

    return 0;
}